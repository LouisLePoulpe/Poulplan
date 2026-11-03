import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'sync_record.dart';

/// The same field was changed differently on both sides since the last
/// synchronization: only the user can decide.
@immutable
class FieldConflict {
  const FieldConflict({
    required this.field,
    required this.localValue,
    required this.remoteValue,
  });

  final String field;
  final Object? localValue;
  final Object? remoteValue;

  @override
  String toString() => 'FieldConflict($field: $localValue ≠ $remoteValue)';
}

@immutable
class MergeResult {
  const MergeResult(this.record, this.conflicts);

  final SyncRecord record;
  final List<FieldConflict> conflicts;
}

const _equality = DeepCollectionEquality();

/// Field-by-field merge of [local] and [remote] versions of a record.
///
/// [base] holds the field versions at the last successful synchronization
/// (null if the record was never synchronized from this device). A field
/// "changed" on a side when its version is newer than the base one (any
/// version counts without base; no version means never edited).
///
/// - Different fields changed on each side: both changes are kept.
/// - The same field changed to different values on both sides: conflict; the
///   most recent value is applied provisionally.
/// - Deleted on one side while edited on the other: conflict on
///   [deletedField]; the record is provisionally kept, with the edits.
MergeResult mergeRecords({
  required SyncRecord local,
  required SyncRecord remote,
  required Map<String, String>? base,
}) {
  bool changed(String? version, String field) {
    if (version == null) return false;
    final baseVersion = base?[field];
    return baseVersion == null || version.compareTo(baseVersion) > 0;
  }

  final fields = <String, Object?>{};
  final versions = <String, String>{};
  final conflicts = <FieldConflict>[];
  final names = {...local.fields.keys, ...remote.fields.keys}
    ..remove(deletedField);

  var localEdited = false;
  var remoteEdited = false;

  void take(String field, {required bool fromLocal}) {
    final source = fromLocal ? local : remote;
    if (source.fields.containsKey(field)) fields[field] = source.fields[field];
    final version = source.versions[field];
    if (version != null) versions[field] = version;
  }

  String? newest(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) >= 0 ? a : b;
  }

  for (final field in names) {
    final lv = local.versions[field];
    final rv = remote.versions[field];
    final localChanged = changed(lv, field);
    final remoteChanged = changed(rv, field);
    localEdited |= localChanged;
    remoteEdited |= remoteChanged;
    final same = _equality.equals(local.fields[field], remote.fields[field]);

    if (same) {
      fields[field] = local.fields.containsKey(field)
          ? local.fields[field]
          : remote.fields[field];
      final version = newest(lv, rv);
      if (version != null) versions[field] = version;
    } else if (localChanged && remoteChanged) {
      conflicts.add(
        FieldConflict(
          field: field,
          localValue: local.fields[field],
          remoteValue: remote.fields[field],
        ),
      );
      take(field, fromLocal: lv!.compareTo(rv!) > 0);
    } else if (localChanged) {
      take(field, fromLocal: true);
    } else if (remoteChanged) {
      take(field, fromLocal: false);
    } else {
      // Neither side changed it since the base: keep the newest copy.
      take(
        field,
        fromLocal:
            (lv ?? '').compareTo(rv ?? '') >= 0 &&
            local.fields.containsKey(field),
      );
    }
  }

  // Tombstone.
  final ld = local.versions[deletedField];
  final rd = remote.versions[deletedField];
  final localDeleted = changed(ld, deletedField) && local.deleted;
  final remoteDeleted = changed(rd, deletedField) && remote.deleted;
  final hasTombstone =
      local.fields.containsKey(deletedField) ||
      remote.fields.containsKey(deletedField);
  if (!hasTombstone) {
    // Nothing to merge for the tombstone.
  } else if ((localDeleted && remoteEdited && !remoteDeleted) ||
      (remoteDeleted && localEdited && !localDeleted)) {
    conflicts.add(
      FieldConflict(
        field: deletedField,
        localValue: local.deleted,
        remoteValue: remote.deleted,
      ),
    );
    fields[deletedField] = false;
    final version = newest(ld, rd);
    if (version != null) versions[deletedField] = version;
  } else if (local.deleted == remote.deleted) {
    fields[deletedField] = local.deleted;
    final version = newest(ld, rd);
    if (version != null) versions[deletedField] = version;
  } else {
    final fromLocal =
        changed(ld, deletedField) &&
        (!changed(rd, deletedField) || ld!.compareTo(rd!) > 0);
    fields[deletedField] = fromLocal ? local.deleted : remote.deleted;
    final version = fromLocal ? ld : rd;
    if (version != null) versions[deletedField] = version;
  }

  return MergeResult(
    local.copyWith(fields: fields, versions: versions),
    conflicts,
  );
}
