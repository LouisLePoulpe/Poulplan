import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/editing/event_draft.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  final created = DateTime.utc(2026, 1, 1);

  test('timed event round-trips through its own zone', () {
    // 09:30–11:00 in New York (EDT, UTC-4).
    final event = CalendarEvent(
      id: 'e',
      title: 'Visio',
      start: DateTime.utc(2026, 6, 1, 13, 30),
      end: DateTime.utc(2026, 6, 1, 15),
      timeZone: 'America/New_York',
      createdAt: created,
      updatedAt: created,
    );
    final draft = EventDraft.fromEvent(event);
    expect(draft.startDay, Day(2026, 6, 1));
    expect(draft.startMinute, 9 * 60 + 30);
    expect(draft.endMinute, 11 * 60);
    final times = draft.resolve();
    expect(times.start, event.start);
    expect(times.end, event.end);
  });

  test('all-day draft uses an inclusive end day', () {
    final event = CalendarEvent(
      id: 'a',
      title: 'Vacances',
      allDay: true,
      start: DateTime.utc(2026, 7, 14),
      end: DateTime.utc(2026, 7, 17),
      timeZone: 'Europe/Paris',
      createdAt: created,
      updatedAt: created,
    );
    final draft = EventDraft.fromEvent(event);
    expect(draft.startDay, Day(2026, 7, 14));
    expect(draft.endDay, Day(2026, 7, 16));
    final times = draft.resolve();
    expect(times.start, DateTime.utc(2026, 7, 14));
    expect(times.end, DateTime.utc(2026, 7, 17));
  });

  test('changing the zone keeps the wall-clock times', () {
    final draft = EventDraft.newTimed(
      day: Day(2026, 1, 15),
      startMinute: 9 * 60,
      timeZone: 'Europe/Paris',
    )..timeZone = 'Asia/Tokyo';
    final times = draft.resolve();
    expect(times.start, DateTime.utc(2026, 1, 15, 0));
    expect(times.end, DateTime.utc(2026, 1, 15, 1));
  });

  test('new timed draft lasts one hour, possibly ending the next day', () {
    final draft = EventDraft.newTimed(
      day: Day(2026, 1, 15),
      startMinute: 23 * 60 + 30,
      timeZone: 'UTC',
    );
    expect(draft.endDay, Day(2026, 1, 16));
    expect(draft.endMinute, 30);
  });

  group('validate', () {
    test('accepts a correct draft', () {
      final draft = EventDraft.newTimed(
        day: Day(2026, 1, 15),
        startMinute: 600,
        timeZone: 'UTC',
      )..title = 'ok';
      expect(draft.validate(), isNull);
    });

    test('rejects an empty title', () {
      final draft = EventDraft.newTimed(
        day: Day(2026, 1, 15),
        startMinute: 600,
        timeZone: 'UTC',
      )..title = '   ';
      expect(draft.validate(), DraftError.emptyTitle);
    });

    test('rejects an end before the start', () {
      final draft =
          EventDraft.newTimed(
              day: Day(2026, 1, 15),
              startMinute: 600,
              timeZone: 'UTC',
            )
            ..title = 'x'
            ..endMinute = 540;
      expect(draft.validate(), DraftError.endBeforeStart);
    });

    test('rejects an all-day end day before the start day', () {
      final draft = EventDraft.newAllDay(day: Day(2026, 1, 15), timeZone: 'UTC')
        ..title = 'x'
        ..endDay = Day(2026, 1, 14);
      expect(draft.validate(), DraftError.endBeforeStart);
    });

    test('rejects an unknown time zone', () {
      final draft = EventDraft.newTimed(
        day: Day(2026, 1, 15),
        startMinute: 600,
        timeZone: 'Mars/Olympus',
      )..title = 'x';
      expect(draft.validate(), DraftError.unknownTimeZone);
    });
  });

  test('switching to all-day and back keeps sensible times', () {
    final draft = EventDraft.newTimed(
      day: Day(2026, 1, 15),
      startMinute: 600,
      timeZone: 'UTC',
    )..allDay = true;
    expect(draft.resolve().end, DateTime.utc(2026, 1, 16));
    draft.allDay = false;
    expect(draft.resolve().start, DateTime.utc(2026, 1, 15, 10));
  });

  test('applyTo updates an existing event', () {
    final event = CalendarEvent(
      id: 'e',
      title: 'Avant',
      start: DateTime.utc(2026, 6, 1, 8),
      end: DateTime.utc(2026, 6, 1, 9),
      timeZone: 'UTC',
      createdAt: created,
      updatedAt: created,
    );
    final draft = EventDraft.fromEvent(event)
      ..title = 'Après'
      ..location = 'Lyon'
      ..categoryId = 'default-work';
    final updated = draft.applyTo(event);
    expect(updated.id, 'e');
    expect(updated.title, 'Après');
    expect(updated.location, 'Lyon');
    expect(updated.categoryId, 'default-work');
  });
}
