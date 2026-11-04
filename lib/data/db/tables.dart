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
@TableIndex(name: 'events_series', columns: {#seriesId, #originalStartUtc})
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

  // Recurrence (schema v2). A series master has `rrule`; an overridden or
  // cancelled occurrence has `seriesId` + `originalStartUtc`.
  TextColumn get rrule => text().nullable()();
  TextColumn get holidayRule => text().withDefault(const Constant('none'))();
  TextColumn get seriesId => text().nullable()();
  IntColumn get originalStartUtc => integer().nullable()();
  BoolColumn get cancelled => boolean().withDefault(const Constant(false))();

  /// Upper bound of a bounded series (ms UTC), null when endless.
  IntColumn get recurrenceEndUtc => integer().nullable()();

  /// JSON list of reminder offsets in minutes (schema v4).
  TextColumn get reminders => text().withDefault(const Constant('[]'))();

  /// Normalized title, description and location (see `normalizeForSearch`).
  TextColumn get searchText => text().withDefault(const Constant(''))();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BirthdayRow')
class Birthdays extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get month => integer()();
  IntColumn get day => integer()();
  IntColumn get birthYear => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Saved search filters (JSON of `SearchQuery`).
@DataClassName('SavedFilterRow')
class SavedFilters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get query => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Files attached to an event (schema v5); metadata only, synchronized.
/// The file itself is on the device (`attachments/<id>/<name>`) and/or in
/// the private cloud Storage (`<user id>/<eventId>/<id>`).
@DataClassName('AttachmentRow')
@TableIndex(name: 'attachments_event', columns: {#eventId})
class Attachments extends Table {
  TextColumn get id => text()();

  /// The event, or the series master for a recurring event.
  TextColumn get eventId => text()();
  TextColumn get name => text()();
  TextColumn get mimeType => text()();
  IntColumn get size => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// What this device has of each attachment file (schema v5, not synced).
@DataClassName('AttachmentFileRow')
class AttachmentFiles extends Table {
  TextColumn get attachmentId => text()();

  /// The file is on this device.
  BoolColumn get stored => boolean().withDefault(const Constant(false))();

  /// Keep the file on this device (downloaded as soon as possible).
  BoolColumn get keepOffline => boolean().withDefault(const Constant(false))();

  /// This device has sent the file to the cloud.
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {attachmentId};
}

/// Synchronization state of a record (schema v3). The pending-changes queue
/// is the set of rows with `dirty = true`: it survives restarts.
@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  TextColumn get entity => text()();
  TextColumn get recordId => text()();

  /// JSON of the fields as last recorded locally.
  TextColumn get fieldValues => text()();

  /// JSON field → HLC version of the last change of each field.
  TextColumn get versions => text()();

  /// JSON of [versions] at the last successful synchronization.
  TextColumn get baseVersions => text().nullable()();
  IntColumn get serverRev => integer().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {entity, recordId};
}

/// Fields changed differently on two devices, waiting for the user.
@DataClassName('SyncConflictRow')
class SyncConflicts extends Table {
  TextColumn get entity => text()();
  TextColumn get recordId => text()();
  TextColumn get field => text()();

  /// JSON-encoded values.
  TextColumn get localValue => text()();
  TextColumn get remoteValue => text()();
  IntColumn get detectedAt => integer()();

  @override
  Set<Column> get primaryKey => {entity, recordId, field};
}

/// Local, device-specific preferences (not synced).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
