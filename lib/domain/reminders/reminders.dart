import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart' as tz;

import '../calendar/day.dart';
import '../calendar/event_timing.dart';
import '../entities/calendar_event.dart';

/// Time of day all-day reminders are relative to (09:00).
const allDayReminderMinute = 9 * 60;

/// A reminder to show at [fireAt] for [event] (an occurrence for series).
@immutable
class ReminderFire {
  ReminderFire({
    required this.event,
    required this.minutesBefore,
    required this.fireAt,
    required this.notificationId,
    DateTime? endsAt,
  }) : endsAt = endsAt ?? event.end;

  final CalendarEvent event;
  final int minutesBefore;
  final DateTime fireAt;

  /// When the event is over: its notification goes away then.
  final DateTime endsAt;

  /// Stable id for the platform notification (positive, 30 bits; ids with
  /// [snoozeIdFlag] are reserved for snoozed reminders).
  final int notificationId;
}

/// Set on the notification id of a snoozed reminder.
const snoozeIdFlag = 0x40000000;

/// Stable positive 30-bit id of the reminder [minutesBefore] of [eventId].
int reminderNotificationId(String eventId, int minutesBefore) {
  // FNV-1a, 32 bits.
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode('$eventId|$minutesBefore')) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final id = hash & 0x3fffffff;
  return id == 0 ? 1 : id;
}

/// The instant [event] is over: its end, or for an all-day event the local
/// midnight after its last day.
DateTime eventEndInstant(CalendarEvent event, tz.Location display) =>
    event.allDay
    ? wallTimeToUtc(display, Day.fromDateTime(event.end), 0)
    : event.end;

/// How long a notification shown at [shownAt] stays: until the event is
/// over. Null when it is already over (nothing to show).
Duration? notificationLifetime(DateTime endsAt, DateTime shownAt) {
  final lifetime = endsAt.difference(shownAt);
  return lifetime > Duration.zero ? lifetime : null;
}

/// Reminders of events that ended in the last two days, whose notification
/// must be removed (Linux: the app closes them itself).
List<ReminderFire> endedReminders(
  Iterable<ReminderFire> fires, {
  required DateTime now,
}) => [
  for (final fire in fires)
    if (!fire.endsAt.isAfter(now) &&
        now.difference(fire.endsAt) <= const Duration(days: 2))
      fire,
];

Iterable<ReminderFire> _fires(
  Iterable<CalendarEvent> events,
  tz.Location display,
) sync* {
  for (final event in events) {
    if (event.kind != EventKind.event || event.cancelled) continue;
    for (final minutes in event.reminders.toSet()) {
      // All-day: wall-clock arithmetic, so that « la veille à 9 h » stays
      // at 09:00 across a DST change.
      final fireAt = event.allDay
          ? wallTimeToUtc(
              display,
              Day.fromDateTime(event.start).addDays(-(minutes ~/ 1440)),
              allDayReminderMinute - minutes % 1440,
            )
          : event.start.subtract(Duration(minutes: minutes));
      yield ReminderFire(
        event: event,
        minutesBefore: minutes,
        fireAt: fireAt,
        notificationId: reminderNotificationId(event.id, minutes),
        endsAt: eventEndInstant(event, display),
      );
    }
  }
}

List<ReminderFire> _sorted(Iterable<ReminderFire> fires) =>
    fires.toList()..sort((a, b) => a.fireAt.compareTo(b.fireAt));

/// Reminders firing after [now] and within [horizon], soonest first, at most
/// [limit] (Android keeps a few hundred alarms per app).
List<ReminderFire> upcomingReminders(
  Iterable<CalendarEvent> events, {
  required DateTime now,
  required Duration horizon,
  required tz.Location display,
  int limit = 400,
}) {
  final end = now.add(horizon);
  return _sorted(
    _fires(
      events,
      display,
    ).where((f) => f.fireAt.isAfter(now) && !f.fireAt.isAfter(end)),
  ).take(limit).toList();
}

/// Reminders that became due in (since, now]: shown at startup when the app
/// was not running (Linux) or by the in-app scheduler.
List<ReminderFire> dueReminders(
  Iterable<CalendarEvent> events, {
  required DateTime since,
  required DateTime now,
  required tz.Location display,
}) => _sorted(
  _fires(
    events,
    display,
  ).where((f) => f.fireAt.isAfter(since) && !f.fireAt.isAfter(now)),
);

/// French label of a reminder offset.
String describeReminder(int minutes, {required bool allDay}) {
  if (allDay) {
    if (minutes == 0) return 'Le jour même à 9 h';
    if (minutes == 1440) return 'La veille à 9 h';
    if (minutes % 1440 == 0) return '${minutes ~/ 1440} jours avant à 9 h';
    return '${_duration(minutes)} avant 9 h';
  }
  if (minutes == 0) return "À l'heure de début";
  return '${_duration(minutes)} avant';
}

String _duration(int minutes) {
  if (minutes % 10080 == 0) {
    final weeks = minutes ~/ 10080;
    return weeks == 1 ? '1 semaine' : '$weeks semaines';
  }
  if (minutes % 1440 == 0) {
    final days = minutes ~/ 1440;
    return days == 1 ? '1 jour' : '$days jours';
  }
  if (minutes >= 60) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
  }
  return '$minutes min';
}

/// All reminders of [events], soonest first.
List<ReminderFire> allReminders(
  Iterable<CalendarEvent> events, {
  required tz.Location display,
}) => _sorted(_fires(events, display));

/// Identifies one firing of a reminder (it changes when the event moves).
String reminderKey(ReminderFire fire) =>
    '${fire.notificationId}@${fire.fireAt.millisecondsSinceEpoch}';

/// Reminders to show right away: their time has passed, they were never
/// shown nor handed to the system ([known] holds their [reminderKey]), the
/// event is not over and they are at most [maxLateness] late.
///
/// Covers events created or moved after their reminder time (an event in
/// 3 minutes with « 10 min avant ») and, on Linux, reminders missed while
/// the app was not running.
List<ReminderFire> remindersToShowNow(
  Iterable<ReminderFire> fires, {
  required DateTime now,
  required Set<String> known,
  Duration maxLateness = const Duration(hours: 24),
}) => [
  for (final fire in fires)
    if (!fire.fireAt.isAfter(now) &&
        now.difference(fire.fireAt) <= maxLateness &&
        fire.endsAt.isAfter(now) &&
        !known.contains(reminderKey(fire)))
      fire,
];
