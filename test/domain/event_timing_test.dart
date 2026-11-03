import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/calendar/event_timing.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location paris;

  setUpAll(() {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
  });

  final created = DateTime.utc(2026, 1, 1);

  CalendarEvent timed(DateTime start, Duration length, String zone) =>
      CalendarEvent(
        id: 'e',
        title: 'e',
        start: start,
        end: start.add(length),
        timeZone: zone,
        createdAt: created,
        updatedAt: created,
      );

  group('wallTimeToUtc', () {
    test('regular winter and summer times', () {
      expect(
        wallTimeToUtc(paris, Day(2026, 1, 15), 9 * 60),
        DateTime.utc(2026, 1, 15, 8),
      );
      expect(
        wallTimeToUtc(paris, Day(2026, 7, 15), 9 * 60),
        DateTime.utc(2026, 7, 15, 7),
      );
    });

    test('a time inside the spring-forward gap is pushed after the gap', () {
      // 29 March 2026, 02:30 does not exist in Paris: becomes 03:30 CEST.
      expect(
        wallTimeToUtc(paris, Day(2026, 3, 29), 2 * 60 + 30),
        DateTime.utc(2026, 3, 29, 1, 30),
      );
    });

    test('an ambiguous fall-back time resolves to its first occurrence', () {
      // 25 October 2026, 02:30 happens twice in Paris: keep the CEST one.
      expect(
        wallTimeToUtc(paris, Day(2026, 10, 25), 2 * 60 + 30),
        DateTime.utc(2026, 10, 25, 0, 30),
      );
    });

    test('minutes past midnight roll over to the next day', () {
      expect(
        wallTimeToUtc(paris, Day(2026, 1, 15), 24 * 60),
        DateTime.utc(2026, 1, 15, 23),
      );
    });
  });

  group('moveToDay', () {
    test('keeps the wall-clock time across a DST change', () {
      // Friday 27 March 09:00 CET → Monday 30 March 09:00 CEST.
      final e = timed(
        DateTime.utc(2026, 3, 27, 8),
        const Duration(hours: 1),
        'Europe/Paris',
      );
      final moved = moveToDay(e, Day(2026, 3, 30), display: paris);
      expect(moved.start, DateTime.utc(2026, 3, 30, 7));
      expect(moved.duration, const Duration(hours: 1));
    });

    test(
      'keeps the wall-clock time of the event zone, not the display one',
      () {
        // 10:00 in New York (EST, UTC-5) displayed in Paris on 2 March.
        final e = timed(
          DateTime.utc(2026, 3, 2, 15),
          const Duration(hours: 2),
          'America/New_York',
        );
        // Moved to 9 March, after the US DST change (8 March): 10:00 EDT.
        final moved = moveToDay(e, Day(2026, 3, 9), display: paris);
        expect(moved.start, DateTime.utc(2026, 3, 9, 14));
        expect(moved.end, DateTime.utc(2026, 3, 9, 16));
      },
    );

    test('the day delta is measured in the display zone', () {
      // 23:30 in New York on 2 March is 05:30 on 3 March in Paris; the user
      // drags it from 3 March to 4 March (Paris view): +1 day.
      final e = timed(
        DateTime.utc(2026, 3, 3, 4, 30),
        const Duration(minutes: 30),
        'America/New_York',
      );
      final moved = moveToDay(e, Day(2026, 3, 4), display: paris);
      expect(moved.start, DateTime.utc(2026, 3, 4, 4, 30));
    });

    test('moves all-day events by whole days', () {
      final e = CalendarEvent(
        id: 'a',
        title: 'a',
        allDay: true,
        start: DateTime.utc(2026, 7, 14),
        end: DateTime.utc(2026, 7, 17),
        timeZone: 'Europe/Paris',
        createdAt: created,
        updatedAt: created,
      );
      final moved = moveToDay(e, Day(2026, 7, 31), display: paris);
      expect(moved.start, DateTime.utc(2026, 7, 31));
      expect(moved.end, DateTime.utc(2026, 8, 3));
    });

    test('same day returns the event unchanged', () {
      final e = timed(
        DateTime.utc(2026, 3, 27, 8),
        const Duration(hours: 1),
        'Europe/Paris',
      );
      expect(moveToDay(e, Day(2026, 3, 27), display: paris), e);
    });
  });

  group('moveToWallTime', () {
    test(
      'drops a timed event at a display wall time, keeping its duration',
      () {
        final e = timed(
          DateTime.utc(2026, 3, 27, 8),
          const Duration(hours: 1),
          'Europe/Paris',
        );
        final moved = moveToWallTime(
          e,
          Day(2026, 3, 30),
          14 * 60 + 15,
          display: paris,
        );
        expect(moved.start, DateTime.utc(2026, 3, 30, 12, 15));
        expect(moved.end, DateTime.utc(2026, 3, 30, 13, 15));
      },
    );

    test('dropping an all-day event on the grid turns it into a 1 h event', () {
      final e = CalendarEvent(
        id: 'a',
        title: 'a',
        allDay: true,
        start: DateTime.utc(2026, 7, 14),
        end: DateTime.utc(2026, 7, 15),
        timeZone: 'Europe/Paris',
        createdAt: created,
        updatedAt: created,
      );
      final moved = moveToWallTime(
        e,
        Day(2026, 7, 14),
        10 * 60,
        display: paris,
      );
      expect(moved.allDay, isFalse);
      expect(moved.start, DateTime.utc(2026, 7, 14, 8));
      expect(moved.duration, const Duration(hours: 1));
    });
  });

  group('snapMinutes', () {
    test('rounds to the nearest step and clamps to the day', () {
      expect(snapMinutes(7, step: 15), 0);
      expect(snapMinutes(8, step: 15), 15);
      expect(snapMinutes(1439, step: 15), 1425);
      expect(snapMinutes(-20, step: 15), 0);
    });
  });
}
