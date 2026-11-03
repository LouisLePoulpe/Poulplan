import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Field holding the tombstone flag, merged like any other field.
const deletedField = '_deleted';

/// A synchronized record: its fields and the HLC version of each field.
@immutable
class SyncRecord {
  SyncRecord({
    required this.entity,
    required this.id,
    required Map<String, Object?> fields,
    required Map<String, String> versions,
  }) : fields = Map.unmodifiable(fields),
       versions = Map.unmodifiable(versions);

  /// Parses the `data` column of `poulplan_records`.
  factory SyncRecord.fromPayload(String entity, Map<String, dynamic> payload) =>
      SyncRecord(
        entity: entity,
        id: payload['id'] as String,
        fields: Map<String, Object?>.from(payload['fields'] as Map? ?? {}),
        versions: Map<String, String>.from(payload['versions'] as Map? ?? {}),
      );

  final String entity;
  final String id;
  final Map<String, Object?> fields;
  final Map<String, String> versions;

  bool get deleted => fields[deletedField] == true;

  Map<String, dynamic> toPayload() => {
    'id': id,
    'fields': fields,
    'versions': versions,
  };

  SyncRecord copyWith({
    Map<String, Object?>? fields,
    Map<String, String>? versions,
  }) => SyncRecord(
    entity: entity,
    id: id,
    fields: fields ?? this.fields,
    versions: versions ?? this.versions,
  );

  static const _equality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is SyncRecord &&
      other.entity == entity &&
      other.id == id &&
      _equality.equals(other.fields, fields) &&
      _equality.equals(other.versions, versions);

  @override
  int get hashCode =>
      Object.hash(entity, id, _equality.hash(fields), _equality.hash(versions));

  @override
  String toString() => 'SyncRecord($entity/$id, $fields)';
}
