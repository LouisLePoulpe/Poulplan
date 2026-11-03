import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:poulplan/domain/reminders/reminders.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location paris;

  setUpAll(() {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
  });

  final created = DateTime.utc(2026, 1, 1);

  CalendarEvent timed(
    String id,
    DateTime start, {
    List<int> reminders = const [10],
    String? seriesId,
    DateTime? originalStart,
  }) => CalendarEvent(
    id: id,
    title: id,
    start: start,
    end: start.add(const Duration(hours: 1)),
    timeZone: 'Europe/Paris',
    reminders: reminders,
    seriesId: seriesId,
    originalStart: originalStart,
    createdAt: created,
    updatedAt: created,
  );

  CalendarEvent allDay(String id, DateTime day, List<int> reminders) =>
      CalendarEvent(
        id: id,
        title: id,
        allDay: true,
        start: day,
        end: day.add(const Duration(days: 1)),
        timeZone: 'Europe/Paris',
        reminders: reminders,
        createdAt: created,
        updatedAt: created,
      );

  List<ReminderFire> upcoming(
    List<CalendarEvent> events,
    DateTime now, {
    Duration horizon = const Duration(days: 30),
  }) => upcomingReminders(events, now: now, horizon: horizon, display: paris);

  test('timed event: fires N minutes before the start', () {
    final fires = upcoming([
      timed('a', DateTime.utc(2026, 3, 10, 8), reminders: [10, 60]),
    ], DateTime.utc(2026, 3, 10, 6));
    expect(fires.map((f) => f.fireAt), [
      DateTime.utc(2026, 3, 10, 7),
      DateTime.utc(2026, 3, 10, 7, 50),
    ]);
    expect(fires.first.minutesBefore, 60);
  });

  test('past and too distant reminders are left out', () {
    final fires = upcoming([
      timed('past', DateTime.utc(2026, 3, 10, 8)),
      timed('soon', DateTime.utc(2026, 3, 11, 8)),
      timed('far', DateTime.utc(2026, 6, 1, 8)),
    ], DateTime.utc(2026, 3, 10, 9));
    expect(fires.map((f) => f.event.id), ['soon']);
  });

  test('all-day reminders are relative to 09:00 local time of the day', () {
    // 29 March 2026 is the spring-forward day in Paris (UTC+2 from 03:00).
    final fires = upcoming([
      allDay('anniv', DateTime.utc(2026, 3, 29), [0, 1440]),
    ], DateTime.utc(2026, 3, 20));
    expect(fires.map((f) => f.fireAt), [
      DateTime.utc(2026, 3, 28, 8), // the day before at 09:00 CET
      DateTime.utc(2026, 3, 29, 7), // the day itself at 09:00 CEST
    ]);
  });

  test('each occurrence of a series has its own reminder id', () {
    final first = timed(
      'm@1',
      DateTime.utc(2026, 3, 10, 8),
      seriesId: 'm',
      originalStart: DateTime.utc(2026, 3, 10, 8),
    );
    final second = timed(
      'm@2',
      DateTime.utc(2026, 3, 17, 8),
      seriesId: 'm',
      originalStart: DateTime.utc(2026, 3, 17, 8),
    );
    final fires = upcoming([first, second], DateTime.utc(2026, 3, 1));
    expect(fires, hasLength(2));
    expect(fires[0].notificationId, isNot(fires[1].notificationId));
  });

  test('notification ids are stable and positive 31-bit integers', () {
    final event = timed('a', DateTime.utc(2026, 3, 10, 8));
    final a = upcoming([event], DateTime.utc(2026, 3, 1)).single;
    final b = upcoming([event], DateTime.utc(2026, 3, 2)).single;
    expect(a.notificationId, b.notificationId);
    expect(a.notificationId, inInclusiveRange(1, 0x7fffffff));
  });

  test('cancelled occurrences and generated events never remind', () {
    final cancelled = timed(
      'c',
      DateTime.utc(2026, 3, 10, 8),
    ).copyWith(cancelled: true);
    final holiday = CalendarEvent(
      id: 'holiday:2026-03-10',
      title: 'Férié',
      allDay: true,
      start: DateTime.utc(2026, 3, 10),
      end: DateTime.utc(2026, 3, 11),
      timeZone: 'UTC',
      kind: EventKind.holiday,
      reminders: const [0],
      createdAt: created,
      updatedAt: created,
    );
    expect(upcoming([cancelled, holiday], DateTime.utc(2026, 3, 1)), isEmpty);
  });

  test('results are sorted and capped', () {
    final events = [
      for (var i = 0; i < 50; i++)
        timed('e$i', DateTime.utc(2026, 3, 2).add(Duration(hours: 50 - i))),
    ];
    final fires = upcomingReminders(
      events,
      now: DateTime.utc(2026, 3, 1),
      horizon: const Duration(days: 30),
      display: paris,
      limit: 20,
    );
    expect(fires, hasLength(20));
    for (var i = 1; i < fires.length; i++) {
      expect(fires[i].fireAt.isBefore(fires[i - 1].fireAt), isFalse);
    }
  });

  test('missed reminders: those due since the last check', () {
    final events = [
      timed('missed', DateTime.utc(2026, 3, 10, 8)), // fires 07:50
      timed('older', DateTime.utc(2026, 3, 9, 8)), // fires the day before
      timed('future', DateTime.utc(2026, 3, 10, 12)),
    ];
    final missed = dueReminders(
      events,
      since: DateTime.utc(2026, 3, 10, 7),
      now: DateTime.utc(2026, 3, 10, 9),
      display: paris,
    );
    expect(missed.map((f) => f.event.id), ['missed']);
  });

  group('describeReminder', () {
    test('timed events', () {
      expect(describeReminder(0, allDay: false), "À l'heure de début");
      expect(describeReminder(10, allDay: false), '10 min avant');
      expect(describeReminder(60, allDay: false), '1 h avant');
      expect(describeReminder(90, allDay: false), '1 h 30 avant');
      expect(describeReminder(1440, allDay: false), '1 jour avant');
      expect(describeReminder(2880, allDay: false), '2 jours avant');
      expect(describeReminder(10080, allDay: false), '1 semaine avant');
    });

    test('all-day events', () {
      expect(describeReminder(0, allDay: true), 'Le jour même à 9 h');
      expect(describeReminder(1440, allDay: true), 'La veille à 9 h');
      expect(describeReminder(2880, allDay: true), '2 jours avant à 9 h');
    });
  });
}
