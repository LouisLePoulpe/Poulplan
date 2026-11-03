import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/repositories/category_repository.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/data/repositories/settings_repository.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/entities/app_settings.dart';

void main() {
  late AppDatabase db;
  late EventRepository events;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    events = EventRepository(db, clock: () => DateTime.utc(2026, 11, 3, 12));
  });

  tearDown(() => db.close());

  test('default categories are seeded on creation', () async {
    final categories = await CategoryRepository(db).watchAll().first;
    expect(categories.map((c) => c.name), [
      'Personnel',
      'Travail',
      'Famille',
      'Santé',
    ]);
  });

  group('EventRepository', () {
    test('create then read back', () async {
      final created = await events.create(
        title: 'Réunion',
        categoryId: 'default-work',
        start: DateTime.utc(2026, 11, 3, 8),
        end: DateTime.utc(2026, 11, 3, 9),
        timeZone: 'Europe/Paris',
      );
      expect(await events.findById(created.id), created);
      expect(created.createdAt, DateTime.utc(2026, 11, 3, 12));
    });

    test('watchBetween only returns overlapping, non-deleted events', () async {
      Future<String> add(String title, DateTime start, DateTime end) async =>
          (await events.create(
            title: title,
            start: start,
            end: end,
            timeZone: 'UTC',
          )).id;

      await add('before', DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 2));
      await add(
        'inside',
        DateTime.utc(2026, 11, 10, 8),
        DateTime.utc(2026, 11, 10, 9),
      );
      await add(
        'overlapping',
        DateTime.utc(2026, 10, 20),
        DateTime.utc(2026, 11, 2),
      );
      final deleted = await add(
        'deleted',
        DateTime.utc(2026, 11, 12, 8),
        DateTime.utc(2026, 11, 12, 9),
      );
      await add('after', DateTime.utc(2027, 1, 5), DateTime.utc(2027, 1, 6));
      await events.delete(deleted);

      final found = await events
          .watchBetween(Day(2026, 11, 1), Day(2026, 11, 30))
          .first;
      expect(found.map((e) => e.title), ['overlapping', 'inside']);
      expect(await events.findById(deleted), isNull);
    });

    test('update changes fields and bumps updatedAt', () async {
      final created = await events.create(
        title: 'Brouillon',
        start: DateTime.utc(2026, 11, 3, 8),
        end: DateTime.utc(2026, 11, 3, 9),
        timeZone: 'UTC',
      );
      final later = EventRepository(
        db,
        clock: () => DateTime.utc(2026, 11, 4, 12),
      );
      await later.update(created.copyWith(title: 'Final'));
      final read = await events.findById(created.id);
      expect(read!.title, 'Final');
      expect(read.updatedAt, DateTime.utc(2026, 11, 4, 12));
    });
  });

  group('SettingsRepository', () {
    test('defaults then persisted values', () async {
      final settings = SettingsRepository(db);
      expect(await settings.watch().first, AppSettings.defaults);
      await settings.setThemeMode(AppThemeMode.dark);
      await settings.setFirstDayOfWeek(DateTime.sunday);
      expect(
        await settings.watch().first,
        const AppSettings(
          themeMode: AppThemeMode.dark,
          firstDayOfWeek: DateTime.sunday,
        ),
      );
    });
  });
}
