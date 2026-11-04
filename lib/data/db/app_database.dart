import 'package:drift/drift.dart';

import '../../domain/search/search_query.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Categories created on first launch. Their ids are fixed so that two
/// devices seeding the same defaults do not produce duplicates once synced.
const defaultCategories = [
  (id: 'default-personal', name: 'Personnel', color: 0xFF1E88E5),
  (id: 'default-work', name: 'Travail', color: 0xFF8F6400),
  (id: 'default-family', name: 'Famille', color: 0xFF43A047),
  (id: 'default-health', name: 'Santé', color: 0xFFE53935),
];

@DriftDatabase(
  tables: [
    Categories,
    Events,
    Settings,
    Birthdays,
    SavedFilters,
    SyncMeta,
    SyncConflicts,
    Attachments,
    AttachmentFiles,
    Routes,
    MapZones,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultCategories();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(events, events.rrule);
        await m.addColumn(events, events.holidayRule);
        await m.addColumn(events, events.seriesId);
        await m.addColumn(events, events.originalStartUtc);
        await m.addColumn(events, events.cancelled);
        await m.addColumn(events, events.recurrenceEndUtc);
        await m.addColumn(events, events.searchText);
        await m.createIndex(eventsSeries);
        await m.createTable(birthdays);
        await m.createTable(savedFilters);
        await _fillSearchText();
      }
      if (from < 3) {
        await m.createTable(syncMeta);
        await m.createTable(syncConflicts);
      }
      if (from < 4) {
        await m.addColumn(events, events.reminders);
      }
      if (from < 5) {
        await m.createTable(attachments);
        await m.createIndex(attachmentsEvent);
        await m.createTable(attachmentFiles);
      }
      if (from < 6) {
        await m.addColumn(events, events.latitude);
        await m.addColumn(events, events.longitude);
        await m.createTable(routes);
        await m.createIndex(routesEvent);
        await m.createTable(mapZones);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedDefaultCategories() async {
    // Same values on every device, so that seeding twice never conflicts
    // once synchronized.
    const now = 0;
    await batch((b) {
      for (final (i, c) in defaultCategories.indexed) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            id: c.id,
            name: c.name,
            color: c.color,
            sortOrder: Value(i),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }

  /// Raw SQL on the v1 columns only: the Dart table class describes the
  /// latest schema, which has columns that do not exist yet at this step.
  Future<void> _fillSearchText() async {
    final rows = await customSelect(
      'SELECT id, title, description, location FROM events',
    ).get();
    for (final r in rows) {
      await customUpdate(
        'UPDATE events SET search_text = ? WHERE id = ?',
        variables: [
          Variable.withString(
            searchTextFor(
              r.read<String>('title'),
              r.read<String>('description'),
              r.readNullable<String>('location'),
            ),
          ),
          Variable.withString(r.read<String>('id')),
        ],
        updates: {events},
      );
    }
  }
}

/// Content of the `searchText` column.
String searchTextFor(String title, String description, String? location) =>
    normalizeForSearch('$title $description ${location ?? ''}');
