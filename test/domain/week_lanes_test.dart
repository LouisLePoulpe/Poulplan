import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/calendar/event_days.dart';
import 'package:poulplan/domain/calendar/week_lanes.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';

void main() {
  final created = DateTime.utc(2026, 1, 1);
  // Week of Monday 2 November 2026.
  final week = List.generate(7, Day(2026, 11, 2).addDays);
  DateTime utc(DateTime d) => d;

  CalendarEvent allDay(String id, Day first, Day last) => CalendarEvent(
    id: id,
    title: id,
    allDay: true,
    start: first.toUtcMidnight(),
    end: last.addDays(1).toUtcMidnight(),
    timeZone: 'UTC',
    createdAt: created,
    updatedAt: created,
  );

  CalendarEvent timed(String id, DateTime start, DateTime end) => CalendarEvent(
    id: id,
    title: id,
    start: start,
    end: end,
    timeZone: 'UTC',
    createdAt: created,
    updatedAt: created,
  );

  WeekLayout layout(List<CalendarEvent> events) {
    final byDay = groupEventsByDay(events, week.first, week.last, utc);
    return layoutWeek(week, byDay, utc);
  }

  test('a multi-day event becomes one span over its columns', () {
    final result = layout([allDay('trip', Day(2026, 11, 4), Day(2026, 11, 6))]);
    final span = result.spans.single;
    expect((span.startColumn, span.endColumn, span.lane), (2, 4, 0));
    expect(span.continuesBefore, isFalse);
    expect(span.continuesAfter, isFalse);
    expect(result.laneCount, 1);
    expect(result.singles.values.every((list) => list.isEmpty), isTrue);
  });

  test('spans crossing the week edges are clipped and marked', () {
    final result = layout([
      allDay('long', Day(2026, 10, 30), Day(2026, 11, 10)),
    ]);
    final span = result.spans.single;
    expect((span.startColumn, span.endColumn), (0, 6));
    expect(span.continuesBefore, isTrue);
    expect(span.continuesAfter, isTrue);
  });

  test('overlapping spans get different lanes, free lanes are reused', () {
    final result = layout([
      allDay('a', Day(2026, 11, 2), Day(2026, 11, 4)),
      allDay('b', Day(2026, 11, 3), Day(2026, 11, 5)),
      allDay('c', Day(2026, 11, 5), Day(2026, 11, 6)),
    ]);
    final lanes = {for (final s in result.spans) s.event.id: s.lane};
    expect(lanes, {'a': 0, 'b': 1, 'c': 0});
    expect(result.laneCount, 2);
  });

  test('longer spans take the upper lanes when they start the same day', () {
    final result = layout([
      allDay('short', Day(2026, 11, 2), Day(2026, 11, 3)),
      allDay('long', Day(2026, 11, 2), Day(2026, 11, 6)),
    ]);
    final lanes = {for (final s in result.spans) s.event.id: s.lane};
    expect(lanes, {'long': 0, 'short': 1});
  });

  test('a timed event over midnight is a span; one-day events stay single', () {
    final result = layout([
      timed(
        'night',
        DateTime.utc(2026, 11, 7, 21),
        DateTime.utc(2026, 11, 8, 1),
      ),
      timed(
        'meeting',
        DateTime.utc(2026, 11, 3, 9),
        DateTime.utc(2026, 11, 3, 10),
      ),
      allDay('holiday', Day(2026, 11, 3), Day(2026, 11, 3)),
    ]);
    expect(result.spans.single.event.id, 'night');
    expect(
      (result.spans.single.startColumn, result.spans.single.endColumn),
      (5, 6),
    );
    expect(result.singles[Day(2026, 11, 3)]!.map((e) => e.id), [
      'holiday',
      'meeting',
    ]);
  });

  test('onlyAllDay keeps timed events out of the spans (week view)', () {
    final byDay = groupEventsByDay(
      [
        timed(
          'night',
          DateTime.utc(2026, 11, 7, 21),
          DateTime.utc(2026, 11, 8, 1),
        ),
        allDay('trip', Day(2026, 11, 4), Day(2026, 11, 5)),
      ],
      week.first,
      week.last,
      utc,
    );
    final result = layoutWeek(week, byDay, utc, onlyAllDay: true);
    expect(result.spans.map((s) => s.event.id), ['trip']);
    expect(result.singles.values.expand((l) => l), isEmpty);
  });
}
