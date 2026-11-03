import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../domain/calendar/day.dart';
import '../../domain/calendar/event_days.dart';
import '../../domain/entities/calendar_event.dart';

String localeOf(BuildContext context) =>
    Localizations.localeOf(context).toString();

/// `09:05` from minutes after midnight.
String formatMinutes(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String formatClock(DateTime wallClock) =>
    formatMinutes(wallClock.hour * 60 + wallClock.minute);

/// `mar. 3 nov. 2026`
String formatDayShort(BuildContext context, Day day) =>
    DateFormat.yMMMEd(localeOf(context)).format(day.toLocalMidnight());

/// `Mardi 3 novembre 2026`
String formatDayLong(BuildContext context, Day day) {
  final locale = localeOf(context);
  return toBeginningOfSentenceCase(
    DateFormat.yMMMMEEEEd(locale).format(day.toLocalMidnight()),
    locale,
  );
}

/// Time range of [event] as displayed on [day]: `09:00 – 10:30`, with `…`
/// when the event continues from/to another day. Null for all-day events.
String? formatEventTimeOnDay(CalendarEvent event, Day day, LocalTime toLocal) {
  if (event.allDay) return null;
  final start = toLocal(event.start);
  final end = toLocal(event.end);
  final from = Day.fromDateTime(start) == day ? formatClock(start) : '…';
  final span = eventDaySpan(event, toLocal);
  final to = span.last == day ? formatClock(end) : '…';
  return '$from – $to';
}
