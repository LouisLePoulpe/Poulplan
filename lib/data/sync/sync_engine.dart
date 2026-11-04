import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../domain/sync/hlc.dart';
import '../../domain/sync/merge.dart';
import '../../domain/sync/sync_record.dart';
import '../db/app_database.dart';
import 'change_recorder.dart';
import 'entity_codecs.dart';
import 'sync_remote.dart';

const _cursorKey = 'sync_cursor';

@immutable
class SyncReport {
  const SyncReport({
    required this.pulled,
    required this.pushed,
    required this.conflicts,
  });

  final int pulled;
  final int pushed;
  final int conflicts;

  @override
  String toString() =>
      'SyncReport(pulled: $pulled, pushed: $pushed, conflicts: $conflicts)';
}

/// Local-first synchronization:
/// 1. every local record not yet tracked is recorded (first connection);
/// 2. remote changes since the last cursor are pulled and merged field by
///    field (real conflicts are stored for the user);
/// 3. pending local changes are pushed with optimistic concurrency; a
///    record changed meanwhile on the server is fetched, merged and pushed
///    again.
class SyncEngine {
  SyncEngine(this._db, this._remote, this._recorder);

  final AppDatabase _db;
  final SyncRemote _remote;
  final ChangeRecorder _recorder;

  /// Revisions re-read before the cursor: a transaction with a smaller
  /// revision can commit after a larger one. Re-applying is harmless.
  static const overlap = 100;
  static const _pushBatch = 100;
  static const _maxRounds = 3;
  static const _equality = DeepCollectionEquality();

  HlcClock get _clock => _recorder.clock;

  Future<SyncReport> sync() async {
    await _trackUnrecorded();
    var pulled = await _pull();
    var pushed = 0;
    for (var round = 0; round < _maxRounds; round++) {
      final result = await _push();
      pushed += result.pushed;
      if (result.conflicts.isEmpty) break;
      for (final (entity, id) in result.conflicts) {
        final remote = await _remote.fetch(entity, id);
        if (remote != null) {
          await _apply(remote);
          pulled++;
        }
      }
    }
    final conflicts = await (_db.selectOnly(
      _db.syncConflicts,
    )..addColumns([countAll()])).map((r) => r.read(countAll())!).getSingle();
    return SyncReport(pulled: pulled, pushed: pushed, conflicts: conflicts);
  }

  Future<void> _trackUnrecorded() async {
    for (final codec in codecs) {
      final tracked =
          await (_db.selectOnly(_db.syncMeta)
                ..addColumns([_db.syncMeta.recordId])
                ..where(_db.syncMeta.entity.equals(codec.entity)))
              .map((r) => r.read(_db.syncMeta.recordId)!)
              .get();
      final ids = (await codec.allIds(_db)).toSet()..removeAll(tracked);
      if (ids.isNotEmpty) await _recorder.record(codec.entity, ids);
    }
  }

  Future<int> _readCursor() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(_cursorKey))).getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 0;
  }

  Future<void> _writeCursor(int value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: _cursorKey, value: '$value'),
      );

  Future<int> _pull() async {
    final cursor = await _readCursor();
    var after = cursor > overlap ? cursor - overlap : 0;
    var maxRev = cursor;
    var count = 0;
    while (true) {
      final page = await _remote.pull(after);
      for (final record in page) {
        if (await _apply(record)) count++;
        if (record.rev > maxRev) maxRev = record.rev;
      }
      if (page.length < 500) break;
      after = page.last.rev;
    }
    if (maxRev != cursor) await _writeCursor(maxRev);
    return count;
  }

  Future<SyncMetaRow?> _meta(String entity, String id) =>
      (_db.select(_db.syncMeta)
            ..where((m) => m.entity.equals(entity) & m.recordId.equals(id)))
          .getSingleOrNull();

  /// An event may arrive before its category (missed pull, category pushed
  /// later): the category is fetched, and when the cloud does not have it
  /// either, the event is stored without it so that the synchronization
  /// never stops on it.
  Future<Map<String, Object?>> _withKnownCategory(
    Map<String, Object?> fields,
  ) async {
    final id = fields['categoryId'];
    if (id is! String) return fields;
    Future<bool> known() async =>
        await (_db.select(
          _db.categories,
        )..where((c) => c.id.equals(id))).getSingleOrNull() !=
        null;
    if (await known()) return fields;
    final category = await _remote.fetch('category', id);
    if (category != null) await _apply(category);
    if (await known()) return fields;
    return {...fields, 'categoryId': null};
  }

  /// Applies a remote record locally. Returns false when it was already
  /// known (overlap re-read).
  Future<bool> _apply(RemoteRecord remote) async {
    if (!codecs.any((c) => c.entity == remote.entity)) return false;
    final meta = await _meta(remote.entity, remote.id);
    if (meta != null && !meta.dirty && (meta.serverRev ?? -1) >= remote.rev) {
      return false;
    }
    final incoming = SyncRecord.fromPayload(remote.entity, remote.data);
    for (final version in incoming.versions.values) {
      _clock.receive(Hlc.parse(version));
    }

    var result = incoming;
    var conflicts = const <FieldConflict>[];
    if (meta != null && meta.dirty) {
      final local = SyncRecord(
        entity: remote.entity,
        id: remote.id,
        fields: jsonDecode(meta.fieldValues) as Map<String, dynamic>,
        versions: Map<String, String>.from(jsonDecode(meta.versions) as Map),
      );
      final base = meta.baseVersions == null
          ? null
          : Map<String, String>.from(jsonDecode(meta.baseVersions!) as Map);
      final merged = mergeRecords(local: local, remote: incoming, base: base);
      result = merged.record;
      conflicts = merged.conflicts;
    }
    final stillDirty =
        !_equality.equals(result.fields, incoming.fields) ||
        !_equality.equals(result.versions, incoming.versions);

    final stored = remote.entity == 'event'
        ? await _withKnownCategory(result.fields)
        : result.fields;
    await _db.transaction(() async {
      await codecFor(remote.entity).write(_db, remote.id, stored);
      await _db
          .into(_db.syncMeta)
          .insertOnConflictUpdate(
            SyncMetaCompanion.insert(
              entity: remote.entity,
              recordId: remote.id,
              fieldValues: jsonEncode(result.fields),
              versions: jsonEncode(result.versions),
              baseVersions: Value(jsonEncode(incoming.versions)),
              serverRev: Value(remote.rev),
              dirty: Value(stillDirty),
            ),
          );
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      for (final c in conflicts) {
        await _db
            .into(_db.syncConflicts)
            .insertOnConflictUpdate(
              SyncConflictsCompanion.insert(
                entity: remote.entity,
                recordId: remote.id,
                field: c.field,
                localValue: jsonEncode(c.localValue),
                remoteValue: jsonEncode(c.remoteValue),
                detectedAt: now,
              ),
            );
      }
    });
    return true;
  }

  Future<({int pushed, List<(String, String)> conflicts})> _push() async {
    var pushed = 0;
    final conflicts = <(String, String)>[];
    final pending = await (_db.select(
      _db.syncMeta,
    )..where((m) => m.dirty.equals(true))).get();
    for (final batch in pending.slices(_pushBatch)) {
      final items = [
        for (final m in batch)
          PushItem(
            entity: m.entity,
            id: m.recordId,
            data: SyncRecord(
              entity: m.entity,
              id: m.recordId,
              fields: jsonDecode(m.fieldValues) as Map<String, dynamic>,
              versions: Map<String, String>.from(jsonDecode(m.versions) as Map),
            ).toPayload(),
            deleted: (jsonDecode(m.fieldValues) as Map)[deletedField] == true,
            baseRev: m.serverRev,
          ),
      ];
      final results = await _remote.push(items);
      for (final r in results) {
        if (r.conflict) {
          conflicts.add((r.entity, r.id));
          continue;
        }
        final sent = batch.firstWhere(
          (m) => m.entity == r.entity && m.recordId == r.id,
        );
        // Only clear the flag if nothing changed locally during the push.
        await (_db.update(_db.syncMeta)..where(
              (m) =>
                  m.entity.equals(r.entity) &
                  m.recordId.equals(r.id) &
                  m.versions.equals(sent.versions),
            ))
            .write(
              SyncMetaCompanion(
                baseVersions: Value(sent.versions),
                serverRev: Value(r.rev),
                dirty: const Value(false),
              ),
            );
        pushed++;
      }
    }
    return (pushed: pushed, conflicts: conflicts);
  }

  /// Number of records waiting to be sent.
  Future<int> pendingCount() =>
      (_db.selectOnly(_db.syncMeta)
            ..addColumns([countAll()])
            ..where(_db.syncMeta.dirty.equals(true)))
          .map((r) => r.read(countAll())!)
          .getSingle();
}
