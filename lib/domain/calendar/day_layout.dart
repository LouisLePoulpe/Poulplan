import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../entities/calendar_event.dart';
import 'day.dart';
import 'event_days.dart';

const minutesPerDay = 24 * 60;

/// A timed event placed on a day's time grid.
@immutable
class PositionedEvent {
  const PositionedEvent({
    required this.event,
    required this.startMinute,
    required this.endMinute,
    required this.column,
    required this.columns,
  });

  final CalendarEvent event;

  /// Wall-clock minutes after local midnight, clipped to the day.
  final int startMinute;
  final int endMinute;

  /// Column of the event among the [columns] of its overlap cluster.
  final int column;
  final int columns;
}

/// Lays out the timed events of [events] that touch [day] on a 24 h grid.
///
/// Overlapping events are split into side-by-side columns; events shorter
/// than [minMinutes] get that minimum height (also used for overlaps).
List<PositionedEvent> layoutTimedEvents(
  Iterable<CalendarEvent> events,
  Day day,
  LocalTime toLocal, {
  int minMinutes = 15,
}) {
  final items = <({CalendarEvent event, int start, int end})>[];
  for (final event in events) {
    if (event.allDay) continue;
    final span = eventDaySpan(event, toLocal);
    if (day.isBefore(span.first) || day.isAfter(span.last)) continue;

    final localStart = toLocal(event.start);
    var start = Day.fromDateTime(localStart) == day
        ? localStart.hour * 60 + localStart.minute
        : 0;
    final localEnd = toLocal(event.end);
    var end = Day.fromDateTime(localEnd) == day
        ? localEnd.hour * 60 + localEnd.minute
        : minutesPerDay;
    // A fall-back change can make the wall-clock end precede the start.
    end = math.max(end, start);
    if (end - start < minMinutes) {
      end = math.min(start + minMinutes, minutesPerDay);
      start = math.min(start, end - minMinutes);
    }
    items.add((event: event, start: start, end: end));
  }
  items.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    final byLength = b.end.compareTo(a.end);
    if (byLength != 0) return byLength;
    return a.event.id.compareTo(b.event.id);
  });

  final result = <PositionedEvent>[];
  var cluster = <({CalendarEvent event, int start, int end, int column})>[];
  var columnEnds = <int>[];
  var clusterEnd = -1;

  void flush() {
    for (final c in cluster) {
      result.add(
        PositionedEvent(
          event: c.event,
          startMinute: c.start,
          endMinute: c.end,
          column: c.column,
          columns: columnEnds.length,
        ),
      );
    }
    cluster = [];
    columnEnds = [];
  }

  for (final item in items) {
    if (item.start >= clusterEnd) flush();
    var column = columnEnds.indexWhere((end) => end <= item.start);
    if (column == -1) {
      column = columnEnds.length;
      columnEnds.add(item.end);
    } else {
      columnEnds[column] = item.end;
    }
    cluster.add((
      event: item.event,
      start: item.start,
      end: item.end,
      column: column,
    ));
    clusterEnd = math.max(clusterEnd, item.end);
  }
  flush();
  return result;
}

/// Ids of busy timed events overlapping at least one other busy timed event.
///
/// Touching events (one ends when the other starts) do not overlap; free and
/// all-day events never count as conflicts.
Set<String> overlappingEventIds(Iterable<CalendarEvent> events) {
  final timed = events.where((e) => !e.allDay && e.busy).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final overlapping = <String>{};
  final active = <CalendarEvent>[];
  for (final event in timed) {
    active.removeWhere((a) => !a.end.isAfter(event.start));
    if (active.isNotEmpty) {
      overlapping.add(event.id);
      overlapping.addAll(active.map((a) => a.id));
    }
    active.add(event);
  }
  return overlapping;
}
