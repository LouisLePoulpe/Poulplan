import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:poulplan/domain/search/search_query.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  late AppDatabase db;
  late EventRepository events;

  setUpAll(tzdata.initializeTimeZones);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    events = EventRepository(db);
  });

  tearDown(() => db.close());

  Future<CalendarEvent> weekly({String rrule = 'FREQ=WEEKLY'}) => events.create(
    title: 'Cours',
    // Mondays 18:00 UTC from 5 January 2026.
    start: DateTime.utc(2026, 1, 5, 18),
    end: DateTime.utc(2026, 1, 5, 19),
    timeZone: 'UTC',
    rrule: rrule,
  );

  Future<List<CalendarEvent>> january() =>
      events.watchBetween(Day(2026, 1, 1), Day(2026, 1, 31)).first;

  test('a weekly series is expanded on every Monday', () async {
    await weekly();
    final shown = await january();
    expect(shown.map((e) => e.start.day), [5, 12, 19, 26]);
    expect(shown.every((e) => e.isOccurrence), isTrue);
  });

  test('editing one occurrence only', () async {
    await weekly();
    final second = (await january())[1];
    await events.saveOccurrence(
      second.copyWith(title: 'Cours (salle B)'),
      SeriesScope.thisOccurrence,
    );
    final shown = await january();
    expect(shown.map((e) => e.title), [
      'Cours',
      'Cours (salle B)',
      'Cours',
      'Cours',
    ]);
    expect(shown[1].isOccurrence, isFalse);
    // Editing the same occurrence again updates the override.
    await events.saveOccurrence(
      shown[1].copyWith(
        start: DateTime.utc(2026, 1, 13, 18),
        end: DateTime.utc(2026, 1, 13, 19),
      ),
      SeriesScope.thisOccurrence,
    );
    final moved = await january();
    expect(moved.map((e) => e.start.day), [5, 13, 19, 26]);
  });

  test('editing the whole series moves every occurrence', () async {
    await weekly();
    final third = (await january())[2];
    await events.saveOccurrence(
      third.copyWith(
        title: 'Cours de piano',
        start: third.start.add(const Duration(hours: 1)),
        end: third.end.add(const Duration(hours: 1)),
      ),
      SeriesScope.all,
    );
    final shown = await january();
    expect(shown.map((e) => (e.start.hour, e.title)).toSet(), {
      (19, 'Cours de piano'),
    });
    expect(shown, hasLength(4));
  });

  test(
    'editing this and the following occurrences splits the series',
    () async {
      await weekly();
      final third = (await january())[2];
      await events.saveOccurrence(
        third.copyWith(title: 'Nouveau cours'),
        SeriesScope.thisAndFollowing,
      );
      final shown = await january();
      expect(shown.map((e) => (e.start.day, e.title)), [
        (5, 'Cours'),
        (12, 'Cours'),
        (19, 'Nouveau cours'),
        (26, 'Nouveau cours'),
      ]);
    },
  );

  test('deleting one occurrence, then undoing it', () async {
    await weekly();
    final second = (await january())[1];
    final undoId = await events.deleteOccurrence(
      second,
      SeriesScope.thisOccurrence,
    );
    expect((await january()).map((e) => e.start.day), [5, 19, 26]);
    await events.uncancel(undoId!);
    expect((await january()).map((e) => e.start.day), [5, 12, 19, 26]);
  });

  test('deleting this and following ends the series', () async {
    await weekly();
    final third = (await january())[2];
    await events.deleteOccurrence(third, SeriesScope.thisAndFollowing);
    expect((await january()).map((e) => e.start.day), [5, 12]);
    final february = await events
        .watchBetween(Day(2026, 2, 1), Day(2026, 2, 28))
        .first;
    expect(february, isEmpty);
  });

  test('deleting the whole series, then restoring it', () async {
    final master = await weekly();
    final first = (await january()).first;
    final undoId = await events.deleteOccurrence(first, SeriesScope.all);
    expect(await january(), isEmpty);
    await events.restore(undoId!);
    expect((await january()).first.seriesId, master.id);
  });

  test('findDisplayed rebuilds a generated occurrence', () async {
    await weekly();
    final third = (await january())[2];
    final found = await events.findDisplayed(third.id);
    expect(found, third);
  });

  test('finished bounded series are not loaded for later windows', () async {
    await weekly(rrule: 'FREQ=WEEKLY;COUNT=2');
    final rows = await events
        .watchRowsBetween(Day(2026, 6, 1), Day(2026, 6, 30))
        .first;
    expect(rows, isEmpty);
  });

  group('search', () {
    Future<void> add(
      String title, {
      String description = '',
      String? location,
      String? categoryId,
      DateTime? start,
      String? rrule,
    }) => events.create(
      title: title,
      description: description,
      location: location,
      categoryId: categoryId,
      start: start ?? DateTime.utc(2026, 5, 1, 9),
      end: (start ?? DateTime.utc(2026, 5, 1, 9)).add(const Duration(hours: 1)),
      timeZone: 'UTC',
      rrule: rrule,
    );

    test('ignores case and accents, all words must match', () async {
      await add('Fête de Noël', location: "École Jules-Ferry");
      await add('Noël chez mamie');
      final results = await events.search(SearchQuery(text: 'NOEL ecole'));
      expect(results.map((e) => e.title), ['Fête de Noël']);
    });

    test('filters by category and period', () async {
      await add(
        'Dentiste',
        categoryId: 'default-health',
        start: DateTime.utc(2026, 2, 1, 9),
      );
      await add(
        'Dentiste',
        categoryId: 'default-health',
        start: DateTime.utc(2026, 9, 1, 9),
      );
      await add(
        'Dentiste du chien',
        categoryId: 'default-family',
        start: DateTime.utc(2026, 9, 2, 9),
      );
      final results = await events.search(
        SearchQuery(
          text: 'dentiste',
          categoryIds: {'default-health'},
          from: Day(2026, 6, 1),
        ),
      );
      expect(results.map((e) => e.start.month), [9]);
    });

    test('a running series matches a later period', () async {
      await add(
        'Yoga',
        start: DateTime.utc(2025, 1, 6, 18),
        rrule: 'FREQ=WEEKLY',
      );
      final results = await events.search(
        SearchQuery(text: 'yoga', from: Day(2026, 6, 1), to: Day(2026, 6, 30)),
      );
      expect(results.single.rrule, 'FREQ=WEEKLY');
    });

    test('stays fast with 10 000 events', () async {
      await db.batch((b) {
        for (var i = 0; i < 10000; i++) {
          final start = DateTime.utc(2020, 1, 1).add(Duration(hours: 7 * i));
          b.insert(
            db.events,
            EventsCompanion.insert(
              id: 'e$i',
              title: 'Événement $i',
              description: Value(i % 100 == 0 ? 'Réunion budget' : ''),
              startUtc: start.millisecondsSinceEpoch,
              endUtc: start.millisecondsSinceEpoch + 3600000,
              timeZone: 'UTC',
              searchText: Value(
                searchTextFor(
                  'Événement $i',
                  i % 100 == 0 ? 'Réunion budget' : '',
                  null,
                ),
              ),
              createdAt: 0,
              updatedAt: 0,
            ),
          );
        }
      });
      final watch = Stopwatch()..start();
      final results = await events.search(SearchQuery(text: 'reunion budget'));
      final searchMs = watch.elapsedMilliseconds;
      expect(results, hasLength(100));

      watch.reset();
      final month = await events
          .watchBetween(Day(2022, 3, 1), Day(2022, 3, 31))
          .first;
      final monthMs = watch.elapsedMilliseconds;
      expect(month, isNotEmpty);
      // Generous bounds for slow CI machines; typically a few ms.
      expect(searchMs, lessThan(500), reason: 'search took $searchMs ms');
      expect(monthMs, lessThan(500), reason: 'month took $monthMs ms');
    });
  });
}
