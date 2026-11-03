import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/sync/hlc.dart';
import '../db/app_database.dart';
import 'entity_codecs.dart';

const _deviceIdKey = 'device_id';
const _hlcKey = 'hlc_last';

/// This device's HLC clock, with its persistent device id.
Future<HlcClock> loadHlcClock(AppDatabase db) async {
  Future<String?> read(String key) async => (await (db.select(
    db.settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  var device = await read(_deviceIdKey);
  if (device == null) {
    device = const Uuid().v4().replaceAll('-', '').substring(0, 12);
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: _deviceIdKey, value: device),
        );
  }
  final last = await read(_hlcKey);
  return HlcClock(device, last: last == null ? null : Hlc.parse(last));
}

/// Records local changes for the synchronization: gives a new HLC version
/// to every field that changed and marks the record as pending.
///
/// Called by the repositories after each write, connected or not, so that
/// offline changes are sent at the next synchronization.
class ChangeRecorder {
  ChangeRecorder(this._db, this.clock);

  final AppDatabase _db;
  final HlcClock clock;
  final _changes = StreamController<void>.broadcast();

  /// Emits after each recorded change (to schedule a synchronization).
  Stream<void> get changes => _changes.stream;

  static const _equality = DeepCollectionEquality();

  Future<void> record(String entity, Iterable<String> ids) async {
    var any = false;
    for (final id in ids) {
      any |= await _recordOne(entity, id);
    }
    if (any) _changes.add(null);
  }

  Future<bool> _recordOne(String entity, String id) async {
    final fields = await codecFor(entity).read(_db, id);
    if (fields == null) return false;
    final meta =
        await (_db.select(_db.syncMeta)
              ..where((m) => m.entity.equals(entity) & m.recordId.equals(id)))
            .getSingleOrNull();
    final previous = meta == null
        ? const <String, Object?>{}
        : jsonDecode(meta.fieldValues) as Map<String, dynamic>;
    final versions = meta == null
        ? <String, String>{}
        : Map<String, String>.from(jsonDecode(meta.versions) as Map);
    var changed = meta == null;
    for (final MapEntry(:key, :value) in fields.entries) {
      if (meta != null &&
          previous.containsKey(key) &&
          _equality.equals(previous[key], value)) {
        continue;
      }
      versions[key] = clock.tick().toString();
      changed = true;
    }
    if (!changed) return false;
    await _db.transaction(() async {
      await _db
          .into(_db.syncMeta)
          .insertOnConflictUpdate(
            SyncMetaCompanion(
              entity: Value(entity),
              recordId: Value(id),
              fieldValues: Value(jsonEncode(fields)),
              versions: Value(jsonEncode(versions)),
              baseVersions: Value(meta?.baseVersions),
              serverRev: Value(meta?.serverRev),
              dirty: const Value(true),
            ),
          );
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: _hlcKey,
              value: clock.last.toString(),
            ),
          );
    });
    return true;
  }

  Future<void> dispose() => _changes.close();
}
