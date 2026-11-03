import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/calendar/day_layout.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';

void main() {
  final created = DateTime.utc(2026, 1, 1);
  // Display in UTC to keep minutes readable.
  DateTime utc(DateTime d) => d;
  final day = Day(2026, 3, 10);

  CalendarEvent timed(
    String id,
    int startH,
    int startM,
    int endH,
    int endM, {
    int dayOffset = 0,
    int endDayOffset = 0,
    bool busy = true,
  }) => CalendarEvent(
    id: id,
    title: id,
    busy: busy,
    start: DateTime.utc(2026, 3, 10 + dayOffset, startH, startM),
    end: DateTime.utc(2026, 3, 10 + endDayOffset, endH, endM),
    timeZone: 'UTC',
    createdAt: created,
    updatedAt: created,
  );

  Map<String, (int, int, int, int)> layout(List<CalendarEvent> events) => {
    for (final p in layoutTimedEvents(events, day, utc))
      p.event.id: (p.startMinute, p.endMinute, p.column, p.columns),
  };

  group('layoutTimedEvents', () {
    test('single event gets the full width', () {
      expect(layout([timed('a', 9, 0, 10, 30)]), {'a': (540, 630, 0, 1)});
    });

    test('overlapping events share columns', () {
      final result = layout([
        timed('a', 9, 0, 11, 0),
        timed('b', 10, 0, 12, 0),
        timed('c', 11, 0, 12, 0),
      ]);
      expect(result['a'], (540, 660, 0, 2));
      expect(result['b'], (600, 720, 1, 2));
      // c starts when a ends: reuses column 0.
      expect(result['c'], (660, 720, 0, 2));
    });

    test('separate clusters are laid out independently', () {
      final result = layout([
        timed('a', 9, 0, 10, 0),
        timed('b', 9, 30, 10, 30),
        timed('c', 14, 0, 15, 0),
      ]);
      expect(result['a']!.$4, 2);
      expect(result['b']!.$4, 2);
      expect(result['c'], (840, 900, 0, 1));
    });

    test('events crossing midnight are clipped to the day', () {
      final result = layout([
        timed('before', 22, 0, 2, 0, dayOffset: -1),
        timed('after', 23, 0, 1, 0, endDayOffset: 1),
      ]);
      expect(result['before'], (0, 120, 0, 1));
      expect(result['after'], (1380, 1440, 0, 1));
    });

    test('very short events get a minimum visible height', () {
      final result = layout([timed('a', 9, 0, 9, 0), timed('b', 9, 10, 9, 20)]);
      expect(result['a'], (540, 555, 0, 2));
      expect(result['b'], (550, 565, 1, 2));
    });

    test('all-day events and events of other days are ignored', () {
      final allDay = CalendarEvent(
        id: 'x',
        title: 'x',
        allDay: true,
        start: DateTime.utc(2026, 3, 10),
        end: DateTime.utc(2026, 3, 11),
        timeZone: 'UTC',
        createdAt: created,
        updatedAt: created,
      );
      expect(
        layout([
          allDay,
          timed('other', 9, 0, 10, 0, dayOffset: 1, endDayOffset: 1),
        ]),
        isEmpty,
      );
    });
  });

  group('overlappingEventIds', () {
    test('flags busy timed events that overlap', () {
      final ids = overlappingEventIds([
        timed('a', 9, 0, 10, 0),
        timed('b', 9, 30, 11, 0),
        timed('c', 11, 0, 12, 0), // touches b: not an overlap
        timed('d', 13, 0, 14, 0),
      ]);
      expect(ids, {'a', 'b'});
    });

    test('free and all-day events never conflict', () {
      final ids = overlappingEventIds([
        timed('a', 9, 0, 10, 0),
        timed('free', 9, 0, 10, 0, busy: false),
        CalendarEvent(
          id: 'allday',
          title: 'allday',
          allDay: true,
          start: DateTime.utc(2026, 3, 10),
          end: DateTime.utc(2026, 3, 11),
          timeZone: 'UTC',
          createdAt: created,
          updatedAt: created,
        ),
      ]);
      expect(ids, isEmpty);
    });

    test('a long event overlapping several short ones', () {
      final ids = overlappingEventIds([
        timed('long', 8, 0, 18, 0),
        timed('x', 9, 0, 10, 0),
        timed('y', 15, 0, 16, 0),
        timed('z', 19, 0, 20, 0),
      ]);
      expect(ids, {'long', 'x', 'y'});
    });
  });
}
