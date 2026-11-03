import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/calendar/event_days.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location paris;
  late tz.Location tokyo;
  late LocalTime inParis;

  setUpAll(() {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
    tokyo = tz.getLocation('Asia/Tokyo');
    inParis = (utc) => tz.TZDateTime.from(utc, paris);
  });

  final created = DateTime.utc(2026, 1, 1);

  CalendarEvent timed(DateTime start, DateTime end, {String title = 'e'}) =>
      CalendarEvent(
        id: title,
        title: title,
        start: start,
        end: end,
        timeZone: 'Europe/Paris',
        createdAt: created,
        updatedAt: created,
      );

  CalendarEvent allDay(Day first, Day lastInclusive, {String title = 'a'}) =>
      CalendarEvent(
        id: title,
        title: title,
        allDay: true,
        start: first.toUtcMidnight(),
        end: lastInclusive.addDays(1).toUtcMidnight(),
        timeZone: 'Europe/Paris',
        createdAt: created,
        updatedAt: created,
      );

  DateTime parisTime(int y, int m, int d, [int h = 0, int min = 0]) =>
      tz.TZDateTime(paris, y, m, d, h, min).toUtc();

  group('eventDaySpan', () {
    test('timed event within a day', () {
      final e = timed(parisTime(2026, 3, 10, 9), parisTime(2026, 3, 10, 10));
      expect(eventDaySpan(e, inParis), (
        first: Day(2026, 3, 10),
        last: Day(2026, 3, 10),
      ));
    });

    test('timed event ending exactly at midnight stays on one day', () {
      final e = timed(parisTime(2026, 3, 10, 22), parisTime(2026, 3, 11));
      expect(eventDaySpan(e, inParis), (
        first: Day(2026, 3, 10),
        last: Day(2026, 3, 10),
      ));
    });

    test('timed event crossing midnight covers two days', () {
      final e = timed(parisTime(2026, 3, 10, 22), parisTime(2026, 3, 11, 1));
      expect(eventDaySpan(e, inParis), (
        first: Day(2026, 3, 10),
        last: Day(2026, 3, 11),
      ));
    });

    test('zero-length event occupies its start day', () {
      final e = timed(parisTime(2026, 3, 11), parisTime(2026, 3, 11));
      expect(eventDaySpan(e, inParis), (
        first: Day(2026, 3, 11),
        last: Day(2026, 3, 11),
      ));
    });

    test('display zone changes the local day of a timed event', () {
      // 20:00 in Paris is 04:00 the next day in Tokyo (UTC+9, no DST).
      final e = timed(parisTime(2026, 3, 10, 20), parisTime(2026, 3, 10, 21));
      expect(eventDaySpan(e, (utc) => tz.TZDateTime.from(utc, tokyo)), (
        first: Day(2026, 3, 11),
        last: Day(2026, 3, 11),
      ));
    });

    test('all-day multi-day event ignores the display zone', () {
      final e = allDay(Day(2026, 7, 14), Day(2026, 7, 16));
      final expected = (first: Day(2026, 7, 14), last: Day(2026, 7, 16));
      expect(eventDaySpan(e, inParis), expected);
      expect(
        eventDaySpan(e, (utc) => tz.TZDateTime.from(utc, tokyo)),
        expected,
      );
    });

    test('event over the spring-forward night (23-hour day)', () {
      // 29 March 2026: Paris jumps from 02:00 to 03:00.
      final e = timed(parisTime(2026, 3, 28, 23), parisTime(2026, 3, 30));
      expect(eventDaySpan(e, inParis), (
        first: Day(2026, 3, 28),
        last: Day(2026, 3, 29),
      ));
    });

    test('event over the fall-back night (25-hour day)', () {
      // 25 October 2026: Paris goes back from 03:00 to 02:00.
      final e = timed(parisTime(2026, 10, 25), parisTime(2026, 10, 26));
      expect(e.duration, const Duration(hours: 25));
      expect(eventDaySpan(e, inParis), (
        first: Day(2026, 10, 25),
        last: Day(2026, 10, 25),
      ));
    });
  });

  group('groupEventsByDay', () {
    test('places multi-day events on every covered day of the range', () {
      final e = allDay(Day(2026, 2, 27), Day(2026, 3, 2));
      final byDay = groupEventsByDay(
        [e],
        Day(2026, 3, 1),
        Day(2026, 3, 31),
        inParis,
      );
      expect(byDay.keys, [Day(2026, 3, 1), Day(2026, 3, 2)]);
    });

    test('ignores events outside the range', () {
      final e = timed(parisTime(2026, 4, 1, 9), parisTime(2026, 4, 1, 10));
      final byDay = groupEventsByDay(
        [e],
        Day(2026, 3, 1),
        Day(2026, 3, 31),
        inParis,
      );
      expect(byDay, isEmpty);
    });

    test('sorts all-day first, then by start time, then by title', () {
      final late = timed(
        parisTime(2026, 3, 5, 18),
        parisTime(2026, 3, 5, 19),
        title: 'late',
      );
      final early = timed(
        parisTime(2026, 3, 5, 8),
        parisTime(2026, 3, 5, 9),
        title: 'early',
      );
      final b = allDay(Day(2026, 3, 5), Day(2026, 3, 5), title: 'b');
      final a = allDay(Day(2026, 3, 5), Day(2026, 3, 5), title: 'a');
      final byDay = groupEventsByDay(
        [late, b, early, a],
        Day(2026, 3, 1),
        Day(2026, 3, 31),
        inParis,
      );
      expect(byDay[Day(2026, 3, 5)]!.map((e) => e.title), [
        'a',
        'b',
        'early',
        'late',
      ]);
    });
  });
}
