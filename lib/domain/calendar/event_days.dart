import '../entities/calendar_event.dart';
import 'day.dart';

/// Converts a UTC instant into wall-clock time of the display time zone.
typedef LocalTime = DateTime Function(DateTime utc);

/// Default converter: the device's local time zone.
DateTime deviceLocalTime(DateTime utc) => utc.toLocal();

/// First and last (inclusive) days covered by an event.
typedef DaySpan = ({Day first, Day last});

/// Days covered by [event] once displayed through [toLocal].
///
/// All-day events keep their floating dates. A timed event ending exactly at
/// midnight does not spill over the next day.
DaySpan eventDaySpan(CalendarEvent event, LocalTime toLocal) {
  if (event.allDay) {
    final first = Day.fromDateTime(event.start);
    final endExclusive = Day.fromDateTime(event.end);
    final last = endExclusive.isAfter(first) ? endExclusive.addDays(-1) : first;
    return (first: first, last: last);
  }
  final start = toLocal(event.start);
  final first = Day.fromDateTime(start);
  if (!event.end.isAfter(event.start)) return (first: first, last: first);
  // The last instant strictly before the end gives the last covered day.
  final last = Day.fromDateTime(
    toLocal(event.end.subtract(const Duration(microseconds: 1))),
  );
  return (first: first, last: last.isBefore(first) ? first : last);
}

/// Groups [events] by each day of [from]…[to] (inclusive) they cover.
///
/// Within a day: all-day events first, then by start, then by title.
Map<Day, List<CalendarEvent>> groupEventsByDay(
  Iterable<CalendarEvent> events,
  Day from,
  Day to,
  LocalTime toLocal,
) {
  final byDay = <Day, List<CalendarEvent>>{};
  for (final event in events) {
    final span = eventDaySpan(event, toLocal);
    var day = span.first.isBefore(from) ? from : span.first;
    final last = span.last.isAfter(to) ? to : span.last;
    while (!day.isAfter(last)) {
      (byDay[day] ??= []).add(event);
      day = day.addDays(1);
    }
  }
  for (final list in byDay.values) {
    list.sort(compareEventsForDisplay);
  }
  return Map.fromEntries(
    byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

/// Display order inside a day: all-day first, then start time, then title.
int compareEventsForDisplay(CalendarEvent a, CalendarEvent b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  final byStart = a.start.compareTo(b.start);
  if (byStart != 0) return byStart;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}
