import 'package:drift/drift.dart';

/// Every synced table carries `createdAt`/`updatedAt` (ms since epoch, UTC)
/// and a `deletedAt` tombstone instead of hard deletes, so that deletions can
/// later be propagated by the cloud sync.
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// See `CalendarEvent` for the meaning of `startUtc`/`endUtc` on all-day
/// events (floating dates encoded as UTC midnights, end exclusive).
@DataClassName('EventRow')
@TableIndex(name: 'events_range', columns: {#startUtc, #endUtc})
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get color => integer().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get videoLink => text().nullable()();
  BoolColumn get busy => boolean().withDefault(const Constant(true))();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  IntColumn get startUtc => integer()();
  IntColumn get endUtc => integer()();
  TextColumn get timeZone => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local, device-specific preferences (not synced).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
