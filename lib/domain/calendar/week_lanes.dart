import 'package:meta/meta.dart';

import '../entities/calendar_event.dart';
import 'day.dart';
import 'event_days.dart';

/// The part of a multi-day event that falls in one week row, drawn as a
/// single bar from [startColumn] to [endColumn] (inclusive) on [lane].
@immutable
class WeekSpan {
  const WeekSpan({
    required this.event,
    required this.startColumn,
    required this.endColumn,
    required this.lane,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final CalendarEvent event;
  final int startColumn;
  final int endColumn;
  final int lane;

  /// The event started in an earlier week / goes on in a later one.
  final bool continuesBefore;
  final bool continuesAfter;
}

@immutable
class WeekLayout {
  const WeekLayout({
    required this.spans,
    required this.laneCount,
    required this.singles,
  });

  final List<WeekSpan> spans;

  /// Lanes reserved at the top of every cell of the row, so bars align.
  final int laneCount;

  /// One-day events of each day, in display order.
  final Map<Day, List<CalendarEvent>> singles;
}

/// Splits the events of a [week] (7 consecutive days) into multi-day spans
/// on lanes and one-day events. With [onlyAllDay] (week view all-day row),
/// timed events are left out entirely.
WeekLayout layoutWeek(
  List<Day> week,
  Map<Day, List<CalendarEvent>> byDay,
  LocalTime toLocal, {
  bool onlyAllDay = false,
}) {
  final first = week.first;
  final last = week.last;
  final candidates = <String, ({CalendarEvent event, DaySpan span})>{};
  final singles = {for (final day in week) day: <CalendarEvent>[]};

  for (final day in week) {
    for (final event in byDay[day] ?? const <CalendarEvent>[]) {
      if (onlyAllDay && !event.allDay) continue;
      final span = eventDaySpan(event, toLocal);
      if (span.first == span.last) {
        singles[day]!.add(event);
      } else {
        candidates[event.id] = (event: event, span: span);
      }
    }
  }

  int column(Day day) => day.differenceInDays(first);
  final ordered = candidates.values.toList()
    ..sort((a, b) {
      final aStart = a.span.first.isBefore(first) ? first : a.span.first;
      final bStart = b.span.first.isBefore(first) ? first : b.span.first;
      final byStart = aStart.compareTo(bStart);
      if (byStart != 0) return byStart;
      final byLength = b.span.last.compareTo(a.span.last);
      if (byLength != 0) return byLength;
      return compareEventsForDisplay(a.event, b.event);
    });

  // lanes[i] = last column used on lane i.
  final lanes = <int>[];
  final spans = <WeekSpan>[];
  for (final c in ordered) {
    final start = column(c.span.first.isBefore(first) ? first : c.span.first);
    final end = column(c.span.last.isAfter(last) ? last : c.span.last);
    var lane = lanes.indexWhere((used) => used < start);
    if (lane == -1) {
      lane = lanes.length;
      lanes.add(end);
    } else {
      lanes[lane] = end;
    }
    spans.add(
      WeekSpan(
        event: c.event,
        startColumn: start,
        endColumn: end,
        lane: lane,
        continuesBefore: c.span.first.isBefore(first),
        continuesAfter: c.span.last.isAfter(last),
      ),
    );
  }
  for (final list in singles.values) {
    list.sort(compareEventsForDisplay);
  }
  return WeekLayout(spans: spans, laneCount: lanes.length, singles: singles);
}
