import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:poulplan/domain/holidays/french_holidays.dart';
import 'package:poulplan/domain/recurrence/expansion.dart';
import 'package:poulplan/domain/recurrence/recurrence_rule.dart';
import 'package:poulplan/domain/recurrence/series_edit.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location paris;

  setUpAll(() {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
  });

  final created = DateTime.utc(2026, 1, 1);

  CalendarEvent master({
    String id = 'm',
    required DateTime start,
    Duration length = const Duration(hours: 1),
    required String rrule,
    bool allDay = false,
    HolidayRule holidayRule = HolidayRule.none,
  }) => CalendarEvent(
    id: id,
    title: 'Série',
    allDay: allDay,
    start: start,
    end: start.add(length),
    timeZone: 'Europe/Paris',
    rrule: rrule,
    holidayRule: holidayRule,
    createdAt: created,
    updatedAt: created,
  );

  CalendarEvent override(
    String id,
    DateTime originalStart, {
    DateTime? start,
    String title = 'Modifiée',
    bool cancelled = false,
  }) => CalendarEvent(
    id: id,
    title: title,
    start: start ?? originalStart,
    end: (start ?? originalStart).add(const Duration(hours: 1)),
    timeZone: 'Europe/Paris',
    seriesId: 'm',
    originalStart: originalStart,
    cancelled: cancelled,
    createdAt: created,
    updatedAt: created,
  );

  List<CalendarEvent> expand(
    List<CalendarEvent> rows,
    Day from,
    Day to, {
    HolidayCalendar? holidays,
  }) => expandEvents(
    rows,
    from: from,
    to: to,
    display: paris,
    holidays: holidays ?? HolidayCalendar(),
  );

  test('weekly 09:00 keeps its wall-clock time across the DST change', () {
    // Thursday 26 March 2026, 09:00 CET = 08:00 UTC.
    final rows = [
      master(start: DateTime.utc(2026, 3, 26, 8), rrule: 'FREQ=WEEKLY'),
    ];
    final result = expand(rows, Day(2026, 3, 20), Day(2026, 4, 5));
    expect(result.map((e) => e.start), [
      DateTime.utc(2026, 3, 26, 8),
      DateTime.utc(2026, 4, 2, 7), // 09:00 CEST
    ]);
    expect(result.every((e) => e.duration == const Duration(hours: 1)), isTrue);
    expect(result.first.seriesId, 'm');
    expect(result.first.originalStart, DateTime.utc(2026, 3, 26, 8));
    expect(result.first.isOccurrence, isTrue);
    expect(parseOccurrenceId(result[1].id), (
      seriesId: 'm',
      originalStart: DateTime.utc(2026, 4, 2, 7),
    ));
  });

  test('cancelled and modified occurrences', () {
    final rows = [
      master(start: DateTime.utc(2026, 1, 5, 8), rrule: 'FREQ=DAILY'),
      override('x1', DateTime.utc(2026, 1, 6, 8), cancelled: true),
      override(
        'x2',
        DateTime.utc(2026, 1, 7, 8),
        start: DateTime.utc(2026, 1, 7, 15),
      ),
    ];
    final result = expand(rows, Day(2026, 1, 5), Day(2026, 1, 8));
    expect(result.map((e) => (e.id, e.start)), [
      (
        'm@${DateTime.utc(2026, 1, 5, 8).millisecondsSinceEpoch}',
        DateTime.utc(2026, 1, 5, 8),
      ),
      ('x2', DateTime.utc(2026, 1, 7, 15)),
      (
        'm@${DateTime.utc(2026, 1, 8, 8).millisecondsSinceEpoch}',
        DateTime.utc(2026, 1, 8, 8),
      ),
    ]);
  });

  test('an occurrence moved into the window from outside appears once', () {
    final rows = [
      master(start: DateTime.utc(2026, 1, 5, 8), rrule: 'FREQ=WEEKLY'),
      // The 12 January occurrence was moved to 20 January.
      override(
        'moved',
        DateTime.utc(2026, 1, 12, 8),
        start: DateTime.utc(2026, 1, 20, 8),
      ),
    ];
    final result = expand(rows, Day(2026, 1, 18), Day(2026, 1, 25));
    expect(
      result.map((e) => e.id),
      ['moved', 'm@${DateTime.utc(2026, 1, 19, 8).millisecondsSinceEpoch}']
        ..sort(),
    );
  });

  group('holiday rule', () {
    // Weekly on Monday from 30 March 2026: 6 April is Easter Monday.
    List<Day> mondays(HolidayRule rule) => expand(
      [
        master(
          start: DateTime.utc(2026, 3, 30, 7),
          rrule: 'FREQ=WEEKLY',
          holidayRule: rule,
        ),
      ],
      Day(2026, 3, 30),
      Day(2026, 4, 13),
    ).map((e) => Day.fromDateTime(tz.TZDateTime.from(e.start, paris))).toList();

    test('none keeps holidays', () {
      expect(mondays(HolidayRule.none), [
        Day(2026, 3, 30),
        Day(2026, 4, 6),
        Day(2026, 4, 13),
      ]);
    });

    test('skip drops occurrences on holidays', () {
      expect(mondays(HolidayRule.skip), [Day(2026, 3, 30), Day(2026, 4, 13)]);
    });

    test('next working day moves to Tuesday', () {
      expect(mondays(HolidayRule.nextWorkingDay), [
        Day(2026, 3, 30),
        Day(2026, 4, 7),
        Day(2026, 4, 13),
      ]);
    });

    test('previous working day moves to Friday', () {
      expect(mondays(HolidayRule.previousWorkingDay), [
        Day(2026, 3, 30),
        Day(2026, 4, 3),
        Day(2026, 4, 13),
      ]);
    });

    test('a moved occurrence keeps its original start as identity', () {
      final moved = expand(
        [
          master(
            start: DateTime.utc(2026, 3, 30, 7),
            rrule: 'FREQ=WEEKLY',
            holidayRule: HolidayRule.nextWorkingDay,
          ),
        ],
        Day(2026, 4, 6),
        Day(2026, 4, 7),
      ).single;
      expect(moved.start, DateTime.utc(2026, 4, 7, 7));
      expect(moved.originalStart, DateTime.utc(2026, 4, 6, 7));
    });
  });

  test('recurring multi-day all-day events', () {
    final rows = [
      master(
        start: DateTime.utc(2026, 7, 4),
        length: const Duration(days: 2),
        rrule: 'FREQ=WEEKLY',
        allDay: true,
      ),
    ];
    final result = expand(rows, Day(2026, 7, 6), Day(2026, 7, 12));
    // The 4–5 July occurrence ends before the window; 11–12 July is inside.
    expect(result.map((e) => (e.start, e.end)), [
      (DateTime.utc(2026, 7, 11), DateTime.utc(2026, 7, 13)),
    ]);
  });

  test('an occurrence started before the window but still running is kept', () {
    final rows = [
      master(
        start: DateTime.utc(2026, 7, 4),
        length: const Duration(days: 3),
        rrule: 'FREQ=WEEKLY',
        allDay: true,
      ),
    ];
    final result = expand(rows, Day(2026, 7, 6), Day(2026, 7, 6));
    expect(result.single.start, DateTime.utc(2026, 7, 4));
  });

  test('plain events pass through and invalid rules degrade gracefully', () {
    final plain = CalendarEvent(
      id: 'p',
      title: 'Simple',
      start: DateTime.utc(2026, 1, 5, 8),
      end: DateTime.utc(2026, 1, 5, 9),
      timeZone: 'UTC',
      createdAt: created,
      updatedAt: created,
    );
    final broken = master(
      id: 'b',
      start: DateTime.utc(2026, 1, 5, 8),
      rrule: 'FREQ=SOMETIMES',
    );
    final result = expand([plain, broken], Day(2026, 1, 1), Day(2026, 1, 31));
    expect(result.map((e) => e.id), ['b', 'p']);
  });

  group('splitRule', () {
    test('UNTIL-less rule: before ends the day before the split', () {
      final split = splitRule(
        RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=MO'),
        Day(2026, 1, 5),
        Day(2026, 2, 2),
      );
      expect(split.before.toString(), 'FREQ=WEEKLY;BYDAY=MO;UNTIL=20260201');
      expect(split.after.toString(), 'FREQ=WEEKLY;BYDAY=MO');
    });

    test('COUNT is shared between both halves', () {
      final split = splitRule(
        RecurrenceRule.parse('FREQ=DAILY;COUNT=10'),
        Day(2026, 1, 1),
        Day(2026, 1, 4),
      );
      expect(split.before.toString(), 'FREQ=DAILY;COUNT=3');
      expect(split.after.toString(), 'FREQ=DAILY;COUNT=7');
    });

    test('splitting at the first occurrence leaves nothing before', () {
      final split = splitRule(
        RecurrenceRule.parse('FREQ=DAILY'),
        Day(2026, 1, 1),
        Day(2026, 1, 1),
      );
      expect(split.beforeIsEmpty, isTrue);
    });
  });
}
