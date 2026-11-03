import 'package:timezone/timezone.dart' as tz;

import '../calendar/day.dart';
import '../calendar/event_days.dart';
import '../calendar/event_timing.dart';
import '../entities/calendar_event.dart';
import '../holidays/french_holidays.dart';
import 'recurrence_rule.dart';

export '../entities/calendar_event.dart' show HolidayRule;

/// Id of the occurrence of series [seriesId] originally starting at
/// [originalStart]: `<seriesId>@<UTC milliseconds>`.
String occurrenceId(String seriesId, DateTime originalStart) =>
    '$seriesId@${originalStart.millisecondsSinceEpoch}';

/// Inverse of [occurrenceId]; null for a plain id.
({String seriesId, DateTime originalStart})? parseOccurrenceId(String id) {
  final at = id.lastIndexOf('@');
  if (at <= 0) return null;
  final ms = int.tryParse(id.substring(at + 1));
  if (ms == null) return null;
  return (
    seriesId: id.substring(0, at),
    originalStart: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
  );
}

/// Turns stored rows (plain events, series masters, overridden occurrences)
/// into the events to display on the days [from]…[to] of the [display] zone.
///
/// The result is sorted by start, then id.
List<CalendarEvent> expandEvents(
  Iterable<CalendarEvent> rows, {
  required Day from,
  required Day to,
  required tz.Location display,
  required HolidayCalendar holidays,
}) {
  final masters = <CalendarEvent>[];
  final overrides = <String, CalendarEvent>{};
  final result = <CalendarEvent>[];
  for (final row in rows) {
    if (row.seriesId != null && row.originalStart != null) {
      overrides[occurrenceId(row.seriesId!, row.originalStart!)] = row;
    } else if (row.rrule != null) {
      masters.add(row);
    } else {
      result.add(row);
    }
  }

  final consumed = <String>{};
  for (final master in masters) {
    RecurrenceRule rule;
    try {
      rule = RecurrenceRule.parse(master.rrule!);
    } on FormatException {
      result.add(master);
      continue;
    }
    for (final occurrence in _occurrences(master, rule, from, to, holidays)) {
      final key = occurrenceId(master.id, occurrence.originalStart!);
      final override = overrides[key];
      if (override != null) {
        consumed.add(key);
        if (!override.cancelled) result.add(override);
      } else {
        result.add(occurrence);
      }
    }
  }
  for (final MapEntry(:key, :value) in overrides.entries) {
    if (!consumed.contains(key) && !value.cancelled) result.add(value);
  }

  DateTime toLocal(DateTime utc) => tz.TZDateTime.from(utc, display);
  final visible = result.where((e) {
    final span = eventDaySpan(e, toLocal);
    return !span.last.isBefore(from) && !span.first.isAfter(to);
  }).toList();
  visible.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.id.compareTo(b.id);
  });
  return visible;
}

Iterable<CalendarEvent> _occurrences(
  CalendarEvent master,
  RecurrenceRule rule,
  Day from,
  Day to,
  HolidayCalendar holidays,
) sync* {
  final zone = master.allDay
      ? tz.UTC
      : locationOrFallback(master.timeZone, tz.UTC);
  final localStart = tz.TZDateTime.from(master.start, zone);
  final startDay = Day.fromDateTime(localStart);
  final startMinute = localStart.hour * 60 + localStart.minute;
  final extra = Duration(
    seconds: localStart.second,
    milliseconds: localStart.millisecond,
  );
  final spanDays = master.duration.inDays;
  // Display days may differ from the series' days by up to a day either way;
  // occurrences that started earlier may still be running.
  final days = rule.occurrenceDays(
    startDay,
    from: from.addDays(-spanDays - 2),
    to: to.addDays(2),
  );

  DateTime startOn(Day day) => master.allDay
      ? day.toUtcMidnight()
      : wallTimeToUtc(zone, day, startMinute).add(extra);

  for (final day in days) {
    final originalStart = startOn(day);
    var actualDay = day;
    if (master.holidayRule != HolidayRule.none && holidays.isHoliday(day)) {
      switch (master.holidayRule) {
        case HolidayRule.skip:
          continue;
        case HolidayRule.nextWorkingDay:
          actualDay = holidays.nextWorkingDay(day);
        case HolidayRule.previousWorkingDay:
          actualDay = holidays.previousWorkingDay(day);
        case HolidayRule.none:
          break;
      }
    }
    final start = actualDay == day ? originalStart : startOn(actualDay);
    yield master.copyWith(
      id: occurrenceId(master.id, originalStart),
      start: start,
      end: start.add(master.duration),
      seriesId: () => master.id,
      originalStart: () => originalStart,
    );
  }
}
