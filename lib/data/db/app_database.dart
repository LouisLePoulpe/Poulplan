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

@DriftDatabase(tables: [Categories, Events, Settings, Birthdays, SavedFilters])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedDefaultCategories() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
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

  Future<void> _fillSearchText() async {
    final rows = await select(events).get();
    for (final r in rows) {
      await (update(events)..where((e) => e.id.equals(r.id))).write(
        EventsCompanion(
          searchText: Value(searchTextFor(r.title, r.description, r.location)),
        ),
      );
    }
  }
}

/// Content of the `searchText` column.
String searchTextFor(String title, String description, String? location) =>
    normalizeForSearch('$title $description ${location ?? ''}');
