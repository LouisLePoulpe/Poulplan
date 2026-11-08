import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/search/search_query.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Large calendars stay fast: 5000 events over three years, 200 series.
/// Limits are generous (slow CI machines); the measured times are printed.
void main() {
  late AppDatabase db;
  late EventRepository events;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    db = AppDatabase(NativeDatabase.memory());
    events = EventRepository(db);
    await db.transaction(() async {
      for (var i = 0; i < 5000; i++) {
        final start = DateTime.utc(2025, 1, 1, 8).add(
          Duration(hours: i * 5 + (i % 7)),
        );
        await events.create(
          title: 'Événement $i ${i.isEven ? 'réunion' : 'sport'}',
          location: 'Salle ${i % 40}',
          start: start,
          end: start.add(const Duration(hours: 1)),
          timeZone: 'Europe/Paris',
        );
      }
      for (var i = 0; i < 200; i++) {
        await events.create(
          title: 'Série $i',
          start: DateTime.utc(2025, 1, 1 + i % 28, 7 + i % 10),
          end: DateTime.utc(2025, 1, 1 + i % 28, 8 + i % 10),
          timeZone: 'Europe/Paris',
          rrule: i.isEven ? 'FREQ=WEEKLY' : 'FREQ=DAILY;INTERVAL=3',
        );
      }
    });
  });

  tearDownAll(() => db.close());

  Future<Duration> time(Future<void> Function() action) async {
    final watch = Stopwatch()..start();
    await action();
    return watch.elapsed;
  }

  test('a month (what the month view shows) loads quickly', () async {
    var count = 0;
    final elapsed = await time(() async {
      final month = await events
          .watchBetween(Day(2026, 10, 26), Day(2026, 12, 6))
          .first;
      count = month.length;
    });
    // ignore: avoid_print
    print('month: $count occurrences in ${elapsed.inMilliseconds} ms');
    expect(count, greaterThan(1000));
    expect(elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('a week loads quickly', () async {
    final elapsed = await time(
      () => events.watchBetween(Day(2026, 11, 2), Day(2026, 11, 8)).first,
    );
    // ignore: avoid_print
    print('week: ${elapsed.inMilliseconds} ms');
    expect(elapsed, lessThan(const Duration(milliseconds: 500)));
  });

  test('search over every event stays quick', () async {
    var found = 0;
    final elapsed = await time(() async {
      found = (await events.search(SearchQuery(text: 'reunion salle 12'))).length;
    });
    // ignore: avoid_print
    print('search: $found results in ${elapsed.inMilliseconds} ms');
    expect(found, greaterThan(0));
    expect(elapsed, lessThan(const Duration(seconds: 1)));
  });
}
