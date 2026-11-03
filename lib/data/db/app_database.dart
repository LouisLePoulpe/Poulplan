import 'package:drift/drift.dart';

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

@DriftDatabase(tables: [Categories, Events, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultCategories();
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
}
