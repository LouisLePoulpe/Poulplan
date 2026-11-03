import 'package:drift/drift.dart';

import '../../domain/sync/sync_record.dart';
import '../db/app_database.dart';
import '../repositories/event_repository.dart';

/// Converts a stored record to/from the field map that is synchronized.
///
/// Local bookkeeping columns (`updatedAt`, derived columns) are not synced;
/// `deletedAt` becomes the [deletedField] flag.
abstract class EntityCodec {
  const EntityCodec();

  String get entity;

  /// Fields of the record [id], or null if it does not exist locally.
  Future<Map<String, Object?>?> read(AppDatabase db, String id);

  /// Creates or replaces the record [id] from synchronized [fields].
  Future<void> write(AppDatabase db, String id, Map<String, Object?> fields);

  Future<List<String>> allIds(AppDatabase db);
}

const codecs = <EntityCodec>[
  _EventCodec(),
  _CategoryCodec(),
  _BirthdayCodec(),
  _SavedFilterCodec(),
];

EntityCodec codecFor(String entity) =>
    codecs.firstWhere((c) => c.entity == entity);

int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

Map<String, Object?> _toFields(
  Map<String, dynamic> json, {
  Set<String> exclude = const {},
}) {
  final fields = <String, Object?>{
    for (final MapEntry(:key, :value) in json.entries)
      if (key != 'id' &&
          key != 'updatedAt' &&
          key != 'deletedAt' &&
          !exclude.contains(key))
        key: value,
  };
  fields[deletedField] = json['deletedAt'] != null;
  return fields;
}

/// JSON for `Row.fromJson`: [defaults] < existing row < synced [fields].
Map<String, dynamic> _toJson(
  String id,
  Map<String, Object?> fields,
  Map<String, dynamic>? existing,
  Map<String, dynamic> defaults,
) {
  final now = _now();
  final deleted = fields[deletedField] == true;
  return {
    ...defaults,
    'createdAt': now,
    ...?existing,
    for (final MapEntry(:key, :value) in fields.entries)
      if (key != deletedField) key: value,
    'id': id,
    'updatedAt': now,
    'deletedAt': deleted ? (existing?['deletedAt'] ?? now) : null,
  };
}

class _EventCodec extends EntityCodec {
  const _EventCodec();

  @override
  String get entity => 'event';

  static const _derived = {'searchText', 'recurrenceEndUtc'};

  @override
  Future<Map<String, Object?>?> read(AppDatabase db, String id) async {
    final row = await (db.select(
      db.events,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toFields(row.toJson(), exclude: _derived);
  }

  @override
  Future<void> write(
    AppDatabase db,
    String id,
    Map<String, Object?> fields,
  ) async {
    final existing = await (db.select(
      db.events,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    final row = EventRow.fromJson(
      _toJson(id, fields, existing?.toJson(), const {
        'title': '',
        'description': '',
        'busy': true,
        'allDay': false,
        'startUtc': 0,
        'endUtc': 0,
        'timeZone': 'UTC',
        'holidayRule': 'none',
        'cancelled': false,
        'searchText': '',
      }),
    );
    // Recompute derived columns through the repository mapping.
    final companion =
        EventRepository.eventToCompanion(EventRepository.rowToEvent(row))
            .copyWith(
              deletedAt: Value(row.deletedAt),
              updatedAt: Value(row.updatedAt),
            );
    await db.into(db.events).insertOnConflictUpdate(companion);
  }

  @override
  Future<List<String>> allIds(AppDatabase db) => (db.selectOnly(
    db.events,
  )..addColumns([db.events.id])).map((r) => r.read(db.events.id)!).get();
}

class _CategoryCodec extends EntityCodec {
  const _CategoryCodec();

  @override
  String get entity => 'category';

  @override
  Future<Map<String, Object?>?> read(AppDatabase db, String id) async {
    final row = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toFields(row.toJson());
  }

  @override
  Future<void> write(
    AppDatabase db,
    String id,
    Map<String, Object?> fields,
  ) async {
    final existing = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    final row = CategoryRow.fromJson(
      _toJson(id, fields, existing?.toJson(), const {
        'name': '',
        'color': 0xFF757575,
        'sortOrder': 0,
      }),
    );
    await db.into(db.categories).insertOnConflictUpdate(row);
  }

  @override
  Future<List<String>> allIds(AppDatabase db) =>
      (db.selectOnly(db.categories)..addColumns([db.categories.id]))
          .map((r) => r.read(db.categories.id)!)
          .get();
}

class _BirthdayCodec extends EntityCodec {
  const _BirthdayCodec();

  @override
  String get entity => 'birthday';

  @override
  Future<Map<String, Object?>?> read(AppDatabase db, String id) async {
    final row = await (db.select(
      db.birthdays,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toFields(row.toJson());
  }

  @override
  Future<void> write(
    AppDatabase db,
    String id,
    Map<String, Object?> fields,
  ) async {
    final existing = await (db.select(
      db.birthdays,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    final row = BirthdayRow.fromJson(
      _toJson(id, fields, existing?.toJson(), const {
        'name': '',
        'month': 1,
        'day': 1,
      }),
    );
    await db.into(db.birthdays).insertOnConflictUpdate(row);
  }

  @override
  Future<List<String>> allIds(AppDatabase db) => (db.selectOnly(
    db.birthdays,
  )..addColumns([db.birthdays.id])).map((r) => r.read(db.birthdays.id)!).get();
}

class _SavedFilterCodec extends EntityCodec {
  const _SavedFilterCodec();

  @override
  String get entity => 'saved_filter';

  @override
  Future<Map<String, Object?>?> read(AppDatabase db, String id) async {
    final row = await (db.select(
      db.savedFilters,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toFields(row.toJson());
  }

  @override
  Future<void> write(
    AppDatabase db,
    String id,
    Map<String, Object?> fields,
  ) async {
    final existing = await (db.select(
      db.savedFilters,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
    final row = SavedFilterRow.fromJson(
      _toJson(id, fields, existing?.toJson(), const {
        'name': '',
        'query': '{}',
      }),
    );
    await db.into(db.savedFilters).insertOnConflictUpdate(row);
  }

  @override
  Future<List<String>> allIds(AppDatabase db) =>
      (db.selectOnly(db.savedFilters)..addColumns([db.savedFilters.id]))
          .map((r) => r.read(db.savedFilters.id)!)
          .get();
}
