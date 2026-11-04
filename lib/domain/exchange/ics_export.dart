import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;

import '../entities/calendar_event.dart';
import '../reminders/reminders.dart';

/// iCalendar (RFC 5545) export of stored events: masters with their RRULE,
/// cancelled occurrences as EXDATE, modified ones as RECURRENCE-ID.
///
/// [events] are the stored rows (not expanded), without the deleted ones.
/// Times keep their IANA zone (`TZID=Europe/Paris`) without VTIMEZONE
/// blocks: calendar applications know these zones.
String exportIcs(
  List<CalendarEvent> events, {
  Map<String, String> categoryNames = const {},
  required DateTime now,
}) {
  final out = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Poulapp//Poulplan//FR',
    'CALSCALE:GREGORIAN',
  ];
  final overrides = <String, List<CalendarEvent>>{};
  for (final e in events) {
    if (e.seriesId != null) (overrides[e.seriesId!] ??= []).add(e);
  }
  final stamp = 'DTSTAMP:${_utc(now)}';
  for (final e in events.where((e) => e.seriesId == null)) {
    final children = overrides[e.id] ?? const <CalendarEvent>[];
    out.addAll(_vevent(e, e, stamp, categoryNames));
    if (e.rrule != null) {
      out.insert(out.length - 1, 'RRULE:${_rrule(e)}');
      for (final c in children.where((c) => c.cancelled)) {
        out.insert(
          out.length - 1,
          _property('EXDATE', c.originalStart ?? c.start, e),
        );
      }
      for (final c in children.where((c) => !c.cancelled)) {
        final block = _vevent(c, e, stamp, categoryNames);
        block.insert(
          block.length - 1,
          _property('RECURRENCE-ID', c.originalStart ?? c.start, e),
        );
        out.addAll(block);
      }
    }
  }
  out.add('END:VCALENDAR');
  return '${out.map(_fold).join('\r\n')}\r\n';
}

const _uidDomain = 'poulplan.poulapp.org';

List<String> _vevent(
  CalendarEvent e,
  CalendarEvent master,
  String stamp,
  Map<String, String> categoryNames,
) {
  final category = e.categoryId == null ? null : categoryNames[e.categoryId];
  return [
    'BEGIN:VEVENT',
    'UID:${master.id}@$_uidDomain',
    stamp,
    _property('DTSTART', e.start, e),
    _property('DTEND', e.end, e),
    'SUMMARY:${_text(e.title)}',
    if (e.description.isNotEmpty) 'DESCRIPTION:${_text(e.description)}',
    if (e.location?.isNotEmpty ?? false) 'LOCATION:${_text(e.location!)}',
    if (e.videoLink?.isNotEmpty ?? false) 'URL:${e.videoLink}',
    if (category != null) 'CATEGORIES:${_text(category)}',
    'TRANSP:${e.busy ? 'OPAQUE' : 'TRANSPARENT'}',
    for (final minutes in e.reminders) ...[
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${_text(e.title)}',
      'TRIGGER:${_trigger(minutes, e.allDay)}',
      'END:VALARM',
    ],
    'END:VEVENT',
  ];
}

/// `NAME;TZID=zone:local`, `NAME:…Z` (UTC) or `NAME;VALUE=DATE:…` (all day,
/// following [owner]).
String _property(String name, DateTime instant, CalendarEvent owner) {
  if (owner.allDay) return '$name;VALUE=DATE:${_date(instant)}';
  if (owner.timeZone == 'UTC') return '$name:${_utc(instant)}';
  final local = tz.TZDateTime.from(instant, tz.getLocation(owner.timeZone));
  return '$name;TZID=${owner.timeZone}:${_date(local)}T${_time(local)}';
}

/// UNTIL is a day in the rule; for timed events RFC 5545 wants an UTC
/// date-time: the last second of that day in the event's zone.
String _rrule(CalendarEvent e) {
  if (e.allDay) return e.rrule!;
  return e.rrule!.replaceAllMapped(RegExp(r'UNTIL=(\d{4})(\d{2})(\d{2})\b'), (
    m,
  ) {
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final next = e.timeZone == 'UTC'
        ? DateTime.utc(y, mo, d + 1)
        : tz.TZDateTime(tz.getLocation(e.timeZone), y, mo, d + 1);
    return 'UNTIL=${_utc(next.subtract(const Duration(seconds: 1)))}';
  });
}

/// All-day reminders fire at 09:00 ([allDayReminderMinute]) n days before.
String _trigger(int minutes, bool allDay) {
  final offset = allDay ? minutes - allDayReminderMinute : minutes;
  return offset >= 0 ? '-PT${offset}M' : 'PT${-offset}M';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${_two(d.month)}${_two(d.day)}';

String _time(DateTime d) => '${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';

String _utc(DateTime d) {
  final u = d.toUtc();
  return '${_date(u)}T${_time(u)}Z';
}

String _text(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n');

/// Lines of at most 75 octets, without cutting a UTF-8 character.
String _fold(String line) {
  if (utf8.encode(line).length <= 75) return line;
  final parts = <String>[];
  final current = StringBuffer();
  var size = 0;
  var limit = 75;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final length = utf8.encode(char).length;
    if (size + length > limit) {
      parts.add(current.toString());
      current.clear();
      size = 0;
      limit = 74; // after the leading space
    }
    current.write(char);
    size += length;
  }
  parts.add(current.toString());
  return parts.join('\r\n ');
}
