import 'package:timezone/timezone.dart' as tz;

import '../calendar/day.dart';
import '../calendar/event_timing.dart';
import '../entities/calendar_event.dart';

enum DraftError { emptyTitle, endBeforeStart, unknownTimeZone }

/// Mutable form state of the event editor.
///
/// Dates and times are wall-clock values in [timeZone] (the event's own
/// zone); all-day events use an inclusive [endDay].
class EventDraft {
  EventDraft({
    this.title = '',
    this.description = '',
    this.categoryId,
    this.color,
    this.location,
    this.videoLink,
    this.busy = true,
    this.allDay = false,
    required this.startDay,
    required this.startMinute,
    required this.endDay,
    required this.endMinute,
    required this.timeZone,
    this.rrule,
    this.holidayRule = HolidayRule.none,
    List<int>? reminders,
  }) : reminders = reminders ?? [];

  /// One-hour event starting at [startMinute] of [day].
  factory EventDraft.newTimed({
    required Day day,
    required int startMinute,
    required String timeZone,
    Duration duration = const Duration(hours: 1),
  }) {
    final end = startMinute + duration.inMinutes;
    return EventDraft(
      startDay: day,
      startMinute: startMinute,
      endDay: day.addDays(end ~/ (24 * 60)),
      endMinute: end % (24 * 60),
      timeZone: timeZone,
    );
  }

  factory EventDraft.newAllDay({required Day day, required String timeZone}) =>
      EventDraft(
        allDay: true,
        startDay: day,
        startMinute: 9 * 60,
        endDay: day,
        endMinute: 10 * 60,
        timeZone: timeZone,
      );

  factory EventDraft.fromEvent(CalendarEvent event) {
    final draft = EventDraft(
      title: event.title,
      description: event.description,
      categoryId: event.categoryId,
      color: event.color,
      location: event.location,
      videoLink: event.videoLink,
      busy: event.busy,
      allDay: event.allDay,
      startDay: Day.fromDateTime(event.start),
      startMinute: 9 * 60,
      endDay: Day.fromDateTime(event.start),
      endMinute: 10 * 60,
      timeZone: event.timeZone,
      rrule: event.rrule,
      holidayRule: event.holidayRule,
      reminders: [...event.reminders],
    );
    if (event.allDay) {
      final endExclusive = Day.fromDateTime(event.end);
      draft.endDay = endExclusive.isAfter(draft.startDay)
          ? endExclusive.addDays(-1)
          : draft.startDay;
    } else {
      final zone = locationOrFallback(event.timeZone, tz.UTC);
      final start = tz.TZDateTime.from(event.start, zone);
      final end = tz.TZDateTime.from(event.end, zone);
      draft
        ..startDay = Day.fromDateTime(start)
        ..startMinute = start.hour * 60 + start.minute
        ..endDay = Day.fromDateTime(end)
        ..endMinute = end.hour * 60 + end.minute;
    }
    return draft;
  }

  String title;
  String description;
  String? categoryId;
  int? color;
  String? location;
  String? videoLink;
  bool busy;
  bool allDay;
  Day startDay;
  int startMinute;
  Day endDay;
  int endMinute;
  String timeZone;

  /// Recurrence rule (RRULE text), null for a single event.
  String? rrule;
  HolidayRule holidayRule;

  /// Reminder offsets in minutes (see `CalendarEvent.reminders`).
  List<int> reminders;

  /// UTC start and end as stored in [CalendarEvent].
  ({DateTime start, DateTime end}) resolve() {
    if (allDay) {
      final last = endDay.isBefore(startDay) ? startDay : endDay;
      return (
        start: startDay.toUtcMidnight(),
        end: last.addDays(1).toUtcMidnight(),
      );
    }
    final zone = locationOrFallback(timeZone, tz.UTC);
    return (
      start: wallTimeToUtc(zone, startDay, startMinute),
      end: wallTimeToUtc(zone, endDay, endMinute),
    );
  }

  DraftError? validate() {
    if (title.trim().isEmpty) return DraftError.emptyTitle;
    if (!tz.timeZoneDatabase.locations.containsKey(timeZone) &&
        timeZone != 'UTC') {
      return DraftError.unknownTimeZone;
    }
    if (allDay) {
      if (endDay.isBefore(startDay)) return DraftError.endBeforeStart;
    } else {
      final times = resolve();
      if (times.end.isBefore(times.start)) return DraftError.endBeforeStart;
    }
    return null;
  }

  /// [event] updated with this draft's values (same id and creation date).
  CalendarEvent applyTo(CalendarEvent event) {
    final times = resolve();
    return event.copyWith(
      title: title.trim(),
      description: description,
      categoryId: () => categoryId,
      color: () => color,
      location: () => _blankToNull(location),
      videoLink: () => _blankToNull(videoLink),
      busy: busy,
      allDay: allDay,
      start: times.start,
      end: times.end,
      timeZone: timeZone,
      rrule: () => rrule,
      holidayRule: holidayRule,
      reminders: (reminders.toSet().toList()..sort()),
    );
  }

  static String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
