import 'package:timezone/timezone.dart' as tz;

import '../entities/calendar_event.dart';
import 'day.dart';

const _msPerMinute = 60 * 1000;
const _msPerHalfDay = 12 * 60 * _msPerMinute;

/// UTC instant of the wall-clock time [minutes] after midnight of [day] in
/// [location].
///
/// - A time skipped by a spring-forward change is read with the offset in
///   force before the change, i.e. pushed after the gap (02:30 → 03:30).
/// - A time repeated by a fall-back change resolves to its first occurrence.
DateTime wallTimeToUtc(tz.Location location, Day day, int minutes) {
  final wall = DateTime.utc(
    day.year,
    day.month,
    day.day,
    0,
    minutes,
  ).millisecondsSinceEpoch;
  final offsetBefore = location
      .timeZone(wall - _msPerHalfDay)
      .offset
      .inMilliseconds;
  final offsetAfter = location
      .timeZone(wall + _msPerHalfDay)
      .offset
      .inMilliseconds;
  final valid = <int>[
    for (final offset in {offsetBefore, offsetAfter})
      if (location.timeZone(wall - offset).offset.inMilliseconds == offset)
        wall - offset,
  ]..sort();
  final utc = valid.isNotEmpty ? valid.first : wall - offsetBefore;
  return DateTime.fromMillisecondsSinceEpoch(utc, isUtc: true);
}

/// Resolves an IANA zone, falling back to [fallback] for unknown names.
tz.Location locationOrFallback(String name, tz.Location fallback) {
  try {
    return tz.getLocation(name);
  } on tz.LocationNotFoundException {
    return fallback;
  }
}

/// Moves [event] to [target] (a day of the [display] zone), as when dragging
/// it to another day of a month or week view.
///
/// Timed events keep their wall-clock start time in their own zone (a 09:00
/// meeting stays at 09:00 after a DST change) and their duration.
CalendarEvent moveToDay(
  CalendarEvent event,
  Day target, {
  required tz.Location display,
}) {
  if (event.allDay) {
    final delta = target.differenceInDays(Day.fromDateTime(event.start));
    if (delta == 0) return event;
    return event.copyWith(
      start: Day.fromDateTime(event.start).addDays(delta).toUtcMidnight(),
      end: Day.fromDateTime(event.end).addDays(delta).toUtcMidnight(),
    );
  }
  final displayed = Day.fromDateTime(tz.TZDateTime.from(event.start, display));
  final delta = target.differenceInDays(displayed);
  if (delta == 0) return event;
  final zone = locationOrFallback(event.timeZone, display);
  final local = tz.TZDateTime.from(event.start, zone);
  final start = wallTimeToUtc(
    zone,
    Day.fromDateTime(local).addDays(delta),
    local.hour * 60 + local.minute,
  ).add(Duration(seconds: local.second, milliseconds: local.millisecond));
  return event.copyWith(start: start, end: start.add(event.duration));
}

/// Moves [event] so that it starts at [minutes] after midnight of [day] in the
/// [display] zone, as when dropping it on a day/week time grid.
///
/// All-day events become one-hour timed events.
CalendarEvent moveToWallTime(
  CalendarEvent event,
  Day day,
  int minutes, {
  required tz.Location display,
}) {
  final start = wallTimeToUtc(display, day, minutes);
  final duration = event.allDay ? const Duration(hours: 1) : event.duration;
  return event.copyWith(allDay: false, start: start, end: start.add(duration));
}

/// Rounds [minutes] to the nearest [step], within the day.
int snapMinutes(int minutes, {int step = 15}) {
  final snapped = (minutes / step).round() * step;
  return snapped.clamp(0, 24 * 60 - step);
}
