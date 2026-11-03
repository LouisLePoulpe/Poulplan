import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'change_recorder.dart';
import 'entity_codecs.dart';

/// Applies the user's choice for a synchronization conflict: the chosen
/// value gets a new version, so it wins on every device at the next sync.
class ConflictResolver {
  ConflictResolver(this._db, this._recorder);

  final AppDatabase _db;
  final ChangeRecorder _recorder;

  Stream<List<SyncConflictRow>> watchAll() => (_db.select(
    _db.syncConflicts,
  )..orderBy([(c) => OrderingTerm.asc(c.detectedAt)])).watch();

  Future<void> resolve(SyncConflictRow conflict, {required bool keepLocal}) {
    return _db.transaction(() async {
      final codec = codecFor(conflict.entity);
      final fields = await codec.read(_db, conflict.recordId);
      if (fields != null) {
        final chosen = jsonDecode(
          keepLocal ? conflict.localValue : conflict.remoteValue,
        );
        await codec.write(_db, conflict.recordId, {
          ...fields,
          conflict.field: chosen,
        });
        // Force a new version even if the provisional value was kept.
        await (_db.update(_db.syncMeta)..where(
              (m) =>
                  m.entity.equals(conflict.entity) &
                  m.recordId.equals(conflict.recordId),
            ))
            .write(
              SyncMetaCompanion(
                fieldValues: Value(
                  jsonEncode({...fields, conflict.field: '\u0000'}),
                ),
              ),
            );
        await _recorder.record(conflict.entity, [conflict.recordId]);
      }
      await (_db.delete(_db.syncConflicts)..where(
            (c) =>
                c.entity.equals(conflict.entity) &
                c.recordId.equals(conflict.recordId) &
                c.field.equals(conflict.field),
          ))
          .go();
    });
  }
}
