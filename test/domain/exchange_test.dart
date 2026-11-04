import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:poulplan/domain/exchange/ics_export.dart';
import 'package:poulplan/domain/exchange/vcard.dart';
import 'package:timezone/data/latest.dart' as tzdata;

CalendarEvent event({
  String id = 'e1',
  String title = 'Piscine',
  String description = '',
  DateTime? start,
  DateTime? end,
  String timeZone = 'Europe/Paris',
  bool allDay = false,
  String? rrule,
  String? seriesId,
  DateTime? originalStart,
  bool cancelled = false,
  List<int> reminders = const [],
  String? categoryId,
  bool busy = true,
}) => CalendarEvent(
  id: id,
  title: title,
  description: description,
  start: start ?? DateTime.utc(2026, 11, 3, 17),
  end: end ?? DateTime.utc(2026, 11, 3, 18),
  timeZone: timeZone,
  allDay: allDay,
  rrule: rrule,
  seriesId: seriesId,
  originalStart: originalStart,
  cancelled: cancelled,
  reminders: reminders,
  categoryId: categoryId,
  busy: busy,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// Unfolded lines of an iCalendar text.
List<String> lines(String ics) => ics
    .replaceAll('\r\n ', '')
    .split('\r\n')
    .where((l) => l.isNotEmpty)
    .toList();

void main() {
  setUpAll(tzdata.initializeTimeZones);
  final now = DateTime.utc(2026, 11, 4, 12);

  group('ICS export', () {
    test('a timed event in its own time zone', () {
      final ics = exportIcs(
        [event(categoryId: 'c1', busy: false)],
        categoryNames: {'c1': 'Sport'},
        now: now,
      );
      expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      expect(
        lines(ics),
        containsAllInOrder([
          'BEGIN:VEVENT',
          'UID:e1@poulplan.poulapp.org',
          'DTSTAMP:20261104T120000Z',
          'DTSTART;TZID=Europe/Paris:20261103T180000',
          'DTEND;TZID=Europe/Paris:20261103T190000',
          'SUMMARY:Piscine',
          'CATEGORIES:Sport',
          'TRANSP:TRANSPARENT',
          'END:VEVENT',
        ]),
      );
    });

    test('UTC events use the Z form', () {
      final ics = exportIcs([event(timeZone: 'UTC')], now: now);
      expect(lines(ics), contains('DTSTART:20261103T170000Z'));
    });

    test('an all-day event uses dates, end exclusive', () {
      final ics = exportIcs([
        event(
          allDay: true,
          start: DateTime.utc(2026, 12, 24),
          end: DateTime.utc(2026, 12, 26),
        ),
      ], now: now);
      expect(
        lines(ics),
        containsAllInOrder([
          'DTSTART;VALUE=DATE:20261224',
          'DTEND;VALUE=DATE:20261226',
        ]),
      );
    });

    test('a series with a cancelled and a modified occurrence', () {
      final ics = exportIcs([
        event(rrule: 'FREQ=WEEKLY'),
        event(
          id: 'x1',
          seriesId: 'e1',
          originalStart: DateTime.utc(2026, 11, 10, 17),
          cancelled: true,
        ),
        event(
          id: 'x2',
          title: 'Piscine tard',
          seriesId: 'e1',
          originalStart: DateTime.utc(2026, 11, 17, 17),
          start: DateTime.utc(2026, 11, 17, 19),
          end: DateTime.utc(2026, 11, 17, 20),
        ),
      ], now: now);
      final l = lines(ics);
      expect(l.where((x) => x == 'BEGIN:VEVENT'), hasLength(2));
      expect(l.where((x) => x == 'UID:e1@poulplan.poulapp.org'), hasLength(2));
      expect(l, contains('RRULE:FREQ=WEEKLY'));
      expect(l, contains('EXDATE;TZID=Europe/Paris:20261110T180000'));
      expect(l, contains('RECURRENCE-ID;TZID=Europe/Paris:20261117T180000'));
      expect(l, contains('DTSTART;TZID=Europe/Paris:20261117T200000'));
    });

    test('UNTIL becomes the end of that day in UTC for timed series', () {
      final ics = exportIcs([
        event(rrule: 'FREQ=DAILY;UNTIL=20261130'),
      ], now: now);
      expect(lines(ics), contains('RRULE:FREQ=DAILY;UNTIL=20261130T225959Z'));
      final allDay = exportIcs([
        event(
          allDay: true,
          start: DateTime.utc(2026, 11, 3),
          end: DateTime.utc(2026, 11, 4),
          rrule: 'FREQ=DAILY;UNTIL=20261130',
        ),
      ], now: now);
      expect(lines(allDay), contains('RRULE:FREQ=DAILY;UNTIL=20261130'));
    });

    test('reminders become alarms', () {
      final ics = exportIcs([
        event(reminders: [10]),
      ], now: now);
      expect(
        lines(ics),
        containsAllInOrder([
          'BEGIN:VALARM',
          'ACTION:DISPLAY',
          'DESCRIPTION:Piscine',
          'TRIGGER:-PT10M',
          'END:VALARM',
        ]),
      );
      // All-day: « la veille à 9 h » is 15 h before the start of the day.
      final allDay = exportIcs([
        event(
          allDay: true,
          start: DateTime.utc(2026, 12, 24),
          end: DateTime.utc(2026, 12, 25),
          reminders: [1440, 0],
        ),
      ], now: now);
      expect(lines(allDay), containsAll(['TRIGGER:-PT900M', 'TRIGGER:PT540M']));
    });

    test('text is escaped and long lines are folded', () {
      final ics = exportIcs([
        event(
          title: 'Réunion; budget, équipe',
          description: 'Ligne 1\nLigne 2 \\ fin ${'é' * 60}',
        ),
      ], now: now);
      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
      final l = lines(ics);
      expect(l, contains(r'SUMMARY:Réunion\; budget\, équipe'));
      expect(l, contains('DESCRIPTION:Ligne 1\\nLigne 2 \\\\ fin ${'é' * 60}'));
    });
  });

  group('vCard import', () {
    test('names and birthdays in the usual formats', () {
      final cards = parseVCardBirthdays(
        'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Léa Martin\r\nBDAY:1996-04-12\r\n'
        'END:VCARD\r\n'
        'BEGIN:VCARD\nVERSION:4.0\nFN:Paul\nBDAY:--0705\nEND:VCARD\n'
        'BEGIN:VCARD\nVERSION:3.0\nN:Durand;Marc;;;\nBDAY;VALUE=date:19800229\n'
        'END:VCARD\n'
        'BEGIN:VCARD\nVERSION:3.0\nFN:Sans date\nEND:VCARD\n'
        'BEGIN:VCARD\nVERSION:3.0\nFN:Apple\n'
        'BDAY;X-APPLE-OMIT-YEAR=1604:1604-11-02\nEND:VCARD\n'
        'BEGIN:VCARD\nVERSION:3.0\nFN:Heure\nBDAY:2001-03-04T00:00:00Z\n'
        'END:VCARD\n'
        'BEGIN:VCARD\nVERSION:3.0\nFN:Faux\nBDAY:2001-02-30\nEND:VCARD\n',
      );
      expect(cards, [
        const VCardBirthday(name: 'Léa Martin', month: 4, day: 12, year: 1996),
        const VCardBirthday(name: 'Paul', month: 7, day: 5),
        const VCardBirthday(name: 'Marc Durand', month: 2, day: 29, year: 1980),
        const VCardBirthday(name: 'Apple', month: 11, day: 2),
        const VCardBirthday(name: 'Heure', month: 3, day: 4, year: 2001),
      ]);
    });

    test('folded lines and quoted-printable (vCard 2.1, Android)', () {
      final cards = parseVCardBirthdays(
        'BEGIN:VCARD\r\nVERSION:2.1\r\n'
        'FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=C3=89lodie =\r\n'
        'Dupr=C3=A9\r\n'
        'BDAY:19900115\r\nEND:VCARD\r\n'
        'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Jean-Ba\r\n ptiste\r\n'
        'BDAY:1985-06-30\r\nEND:VCARD\r\n',
      );
      expect(cards, [
        const VCardBirthday(
          name: 'Élodie Dupré',
          month: 1,
          day: 15,
          year: 1990,
        ),
        const VCardBirthday(
          name: 'Jean-Baptiste',
          month: 6,
          day: 30,
          year: 1985,
        ),
      ]);
    });

    test('a birthday date alone (Android contacts)', () {
      expect(parseBirthdayDate('1996-04-12'), (month: 4, day: 12, year: 1996));
      expect(parseBirthdayDate('--04-12'), (month: 4, day: 12, year: null));
      expect(parseBirthdayDate('n/a'), isNull);
    });
  });
}
