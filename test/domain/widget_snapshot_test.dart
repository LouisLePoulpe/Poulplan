import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:poulplan/domain/widgets/widget_snapshot.dart';

void main() {
  final created = DateTime.utc(2026, 1, 1);

  CalendarEvent event(
    String id,
    DateTime start,
    Duration length, {
    bool allDay = false,
    EventKind kind = EventKind.event,
    int? color,
  }) => CalendarEvent(
    id: id,
    title: id,
    allDay: allDay,
    start: start,
    end: start.add(length),
    timeZone: 'UTC',
    kind: kind,
    color: color,
    createdAt: created,
    updatedAt: created,
  );

  DateTime utc(DateTime d) => d;
  int colorOf(CalendarEvent e) => e.color ?? 0xFF000000;

  WidgetSnapshot build(List<CalendarEvent> events, DateTime now) =>
      buildWidgetSnapshot(
        events,
        now: now,
        toLocal: utc,
        colorOf: colorOf,
        firstDayOfWeek: DateTime.monday,
      );

  test('upcoming: running and future events, soonest first', () {
    final snapshot = build([
      event('later', DateTime.utc(2026, 11, 5, 9), const Duration(hours: 1)),
      event('finished', DateTime.utc(2026, 11, 3, 6), const Duration(hours: 1)),
      event('running', DateTime.utc(2026, 11, 3, 9), const Duration(hours: 2)),
    ], DateTime.utc(2026, 11, 3, 10));
    expect(snapshot.upcoming.map((e) => e.id), ['running', 'later']);
  });

  test('all-day events of today are upcoming until the end of the day', () {
    final snapshot = build([
      event(
        'today',
        DateTime.utc(2026, 11, 3),
        const Duration(days: 1),
        allDay: true,
      ),
    ], DateTime.utc(2026, 11, 3, 23));
    expect(snapshot.upcoming.single.id, 'today');
    expect(snapshot.upcoming.single.allDay, isTrue);
  });

  test('holidays and birthdays are shown, school holidays are not listed', () {
    final snapshot = build([
      event(
        'holiday:2026-11-11',
        DateTime.utc(2026, 11, 11),
        const Duration(days: 1),
        allDay: true,
        kind: EventKind.holiday,
      ),
      event(
        'school',
        DateTime.utc(2026, 12, 19),
        const Duration(days: 16),
        allDay: true,
        kind: EventKind.schoolHoliday,
      ),
    ], DateTime.utc(2026, 11, 3, 10));
    expect(snapshot.upcoming.map((e) => e.id), ['holiday:2026-11-11']);
    expect(snapshot.upcoming.single.openable, isFalse);
  });

  test('at most [limit] upcoming events', () {
    final events = [
      for (var i = 0; i < 40; i++)
        event(
          'e$i',
          DateTime.utc(2026, 11, 4, 0, i),
          const Duration(minutes: 5),
        ),
    ];
    final snapshot = buildWidgetSnapshot(
      events,
      now: DateTime.utc(2026, 11, 3),
      toLocal: utc,
      colorOf: colorOf,
      firstDayOfWeek: DateTime.monday,
      limit: 15,
    );
    expect(snapshot.upcoming, hasLength(15));
  });

  test('busy days carry up to three colors, multi-day events on each day', () {
    final snapshot = build([
      event(
        'trip',
        DateTime.utc(2026, 11, 12),
        const Duration(days: 3),
        allDay: true,
        color: 0xFF00FF00,
      ),
      for (var i = 0; i < 5; i++)
        event(
          'm$i',
          DateTime.utc(2026, 11, 20, 8 + i),
          const Duration(hours: 1),
          color: 0xFF000000 + i,
        ),
    ], DateTime.utc(2026, 11, 3));
    expect(snapshot.busyDays[Day(2026, 11, 12)], [0xFF00FF00]);
    expect(snapshot.busyDays[Day(2026, 11, 14)], [0xFF00FF00]);
    expect(snapshot.busyDays[Day(2026, 11, 15)], isNull);
    expect(snapshot.busyDays[Day(2026, 11, 20)], hasLength(3));
  });

  test('json round-trip keeps what the native widgets need', () {
    final snapshot = build([
      event('e', DateTime.utc(2026, 11, 4, 9), const Duration(hours: 1)),
    ], DateTime.utc(2026, 11, 3));
    final json = snapshot.toJson();
    expect(json['version'], 1);
    expect(json['firstDayOfWeek'], 1);
    final upcoming = (json['upcoming'] as List).single as Map;
    expect(upcoming['id'], 'e');
    expect(
      upcoming['start'],
      DateTime.utc(2026, 11, 4, 9).millisecondsSinceEpoch,
    );
    expect(upcoming['localDay'], '2026-11-04');
    expect(upcoming['time'], '09:00');
    expect((json['busyDays'] as Map)['2026-11-04'], isNotEmpty);
  });

  test('agenda: every event of each day, finished ones included', () {
    final snapshot = build([
      event('morning', DateTime.utc(2026, 11, 3, 8), const Duration(hours: 1)),
      event('evening', DateTime.utc(2026, 11, 3, 19), const Duration(hours: 1)),
      event(
        'trip',
        DateTime.utc(2026, 11, 3),
        const Duration(days: 3),
        allDay: true,
      ),
      event(
        'next week',
        DateTime.utc(2026, 11, 20, 8),
        const Duration(hours: 1),
      ),
    ], DateTime.utc(2026, 11, 3, 12));
    // Finished « morning » is kept: the Day widget shows the whole day.
    expect(snapshot.agenda[Day(2026, 11, 3)]!.map((e) => e.id), [
      'trip',
      'morning',
      'evening',
    ]);
    // A multi-day event is listed on each of its days.
    expect(snapshot.agenda[Day(2026, 11, 5)]!.map((e) => e.id), ['trip']);
    // Only the next week is kept.
    expect(
      snapshot.agenda.keys.every((d) => !d.isAfter(Day(2026, 11, 10))),
      isTrue,
    );
    expect(snapshot.agenda[Day(2026, 11, 3)]!.first.endTime, isNull);
    expect(snapshot.agenda[Day(2026, 11, 3)]![1].endTime, '09:00');
  });

  test('agenda json is keyed by day', () {
    final json = build([
      event('e', DateTime.utc(2026, 11, 4, 9), const Duration(hours: 1)),
    ], DateTime.utc(2026, 11, 3)).toJson();
    final agenda = json['agenda'] as Map;
    expect(((agenda['2026-11-04'] as List).single as Map)['endTime'], '10:00');
  });
}
