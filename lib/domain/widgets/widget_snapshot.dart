import 'package:meta/meta.dart';

import '../calendar/day.dart';
import '../calendar/event_days.dart';
import '../entities/calendar_event.dart';

/// One event in the « à venir » list of the widgets.
@immutable
class WidgetEntry {
  const WidgetEntry({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.localDay,
    required this.time,
    required this.color,
    required this.location,
    required this.openable,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  /// Day of the start in the display zone (floating date for all-day).
  final Day localDay;

  /// `HH:MM` in the display zone, null for all-day events.
  final String? time;
  final int color;
  final String? location;

  /// Whether tapping it opens the event editor (stored events only).
  final bool openable;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'allDay': allDay,
    'localDay': localDay.toString(),
    'time': time,
    'color': color,
    'location': location,
    'openable': openable,
  };
}

/// What the home screen / desktop widgets display. They re-read it
/// themselves (e.g. after midnight) without the app running.
@immutable
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.generatedAt,
    required this.firstDayOfWeek,
    required this.upcoming,
    required this.busyDays,
  });

  final DateTime generatedAt;
  final int firstDayOfWeek;
  final List<WidgetEntry> upcoming;

  /// Colors (at most three) of the events of each local day.
  final Map<Day, List<int>> busyDays;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'generatedAt': generatedAt.millisecondsSinceEpoch,
    'firstDayOfWeek': firstDayOfWeek,
    'upcoming': [for (final e in upcoming) e.toJson()],
    'busyDays': {
      for (final MapEntry(:key, :value) in busyDays.entries)
        key.toString(): value,
    },
  };
}

String _clock(DateTime local) =>
    '${local.hour.toString().padLeft(2, '0')}:'
    '${local.minute.toString().padLeft(2, '0')}';

/// Builds the widget data from the displayed [events] (recurrences already
/// expanded, holidays and birthdays included).
WidgetSnapshot buildWidgetSnapshot(
  Iterable<CalendarEvent> events, {
  required DateTime now,
  required LocalTime toLocal,
  required int Function(CalendarEvent) colorOf,
  required int firstDayOfWeek,
  int limit = 20,
}) {
  final today = Day.fromDateTime(toLocal(now));
  final shown = events
      .where((e) => !e.cancelled && e.kind != EventKind.schoolHoliday)
      .toList();

  final upcoming = <WidgetEntry>[];
  for (final e in shown) {
    final span = eventDaySpan(e, toLocal);
    final running = e.allDay
        ? !span.last.isBefore(today)
        : e.end.isAfter(now) || (e.end == e.start && !e.start.isBefore(now));
    if (!running) continue;
    final localStart = toLocal(e.start);
    upcoming.add(
      WidgetEntry(
        id: e.id,
        title: e.title,
        start: e.start,
        end: e.end,
        allDay: e.allDay,
        localDay: span.first,
        time: e.allDay ? null : _clock(localStart),
        color: colorOf(e),
        location: e.location,
        openable: e.kind == EventKind.event,
      ),
    );
  }
  upcoming.sort((a, b) {
    final byDay = a.localDay.compareTo(b.localDay);
    if (byDay != 0) return byDay;
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.title.compareTo(b.title);
  });

  final busy = <Day, List<int>>{};
  for (final e in shown) {
    final span = eventDaySpan(e, toLocal);
    for (var d = span.first; !d.isAfter(span.last); d = d.addDays(1)) {
      final colors = busy.putIfAbsent(d, () => []);
      final color = colorOf(e);
      if (colors.length < 3 && !colors.contains(color)) colors.add(color);
    }
  }

  return WidgetSnapshot(
    generatedAt: now,
    firstDayOfWeek: firstDayOfWeek,
    upcoming: upcoming.take(limit).toList(),
    busyDays: busy,
  );
}
