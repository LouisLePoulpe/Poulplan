import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/entities/birthday.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:poulplan/domain/holidays/school_holidays.dart';
import 'package:poulplan/domain/search/search_query.dart';

void main() {
  group('normalizeForSearch', () {
    test('lowercases and removes accents', () {
      expect(normalizeForSearch("Noël à l'École"), "noel a l'ecole");
      expect(normalizeForSearch('ŒUVRE Ça  Va'), 'oeuvre ca va');
    });

    test('query tokens must all match', () {
      final query = SearchQuery(text: 'ecole noel');
      expect(query.matchesText("Fête de Noël de l'école"), isTrue);
      expect(query.matchesText('Noël'), isFalse);
      expect(SearchQuery().matchesText('anything'), isTrue);
    });
  });

  group('SearchQuery', () {
    test('json round-trip', () {
      final query = SearchQuery(
        text: 'dentiste',
        categoryIds: {'default-health'},
        from: Day(2026, 1, 1),
        to: Day(2026, 12, 31),
      );
      expect(SearchQuery.fromJson(query.toJson()), query);
    });

    test('empty query is detected', () {
      expect(SearchQuery().isEmpty, isTrue);
      expect(SearchQuery(text: '  ').isEmpty, isTrue);
      expect(SearchQuery(categoryIds: {'x'}).isEmpty, isFalse);
    });
  });

  group('school holidays', () {
    const json = '''
{
 "endExclusive": true,
 "periods": [
  {"zone": "A", "name": "Vacances de la Toussaint", "start": "2026-10-17", "end": "2026-11-02"},
  {"zone": "B", "name": "Vacances de la Toussaint", "start": "2026-10-17", "end": "2026-11-02"},
  {"zone": "A", "name": "Vacances de Noël", "start": "2026-12-19", "end": "2027-01-04"}
 ]
}''';

    test('parses periods and filters by zone and range', () {
      final calendar = SchoolHolidayCalendar.fromJson(json);
      final periods = calendar.between(
        'A',
        Day(2026, 10, 30),
        Day(2026, 12, 31),
      );
      expect(periods.map((p) => p.name), [
        'Vacances de la Toussaint',
        'Vacances de Noël',
      ]);
      expect(periods.first.lastDay, Day(2026, 11, 1));
      expect(
        calendar.between('C', Day(2026, 1, 1), Day(2027, 12, 31)),
        isEmpty,
      );
    });

    test('periods become all-day display events', () {
      final calendar = SchoolHolidayCalendar.fromJson(json);
      final event = calendar
          .between('A', Day(2026, 10, 1), Day(2026, 10, 31))
          .single
          .toEvent();
      expect(event.kind, EventKind.schoolHoliday);
      expect(event.allDay, isTrue);
      expect(event.start, DateTime.utc(2026, 10, 17));
      expect(event.end, DateTime.utc(2026, 11, 2));
    });
  });

  group('birthdays', () {
    final created = DateTime.utc(2026, 1, 1);

    test('occurrences with age when the birth year is known', () {
      final birthday = Birthday(
        id: 'b',
        name: 'Léa',
        month: 3,
        day: 14,
        birthYear: 1996,
        createdAt: created,
        updatedAt: created,
      );
      final events = birthday.occurrences(Day(2026, 1, 1), Day(2027, 12, 31));
      expect(events.map((e) => (e.start, e.title)), [
        (DateTime.utc(2026, 3, 14), 'Anniversaire de Léa (30 ans)'),
        (DateTime.utc(2027, 3, 14), 'Anniversaire de Léa (31 ans)'),
      ]);
      expect(events.first.kind, EventKind.birthday);
      expect(events.first.allDay, isTrue);
    });

    test('29 February is celebrated on 28 February in common years', () {
      final birthday = Birthday(
        id: 'b',
        name: 'Max',
        month: 2,
        day: 29,
        createdAt: created,
        updatedAt: created,
      );
      final days = birthday
          .occurrences(Day(2027, 1, 1), Day(2028, 12, 31))
          .map((e) => Day.fromDateTime(e.start));
      expect(days, [Day(2027, 2, 28), Day(2028, 2, 29)]);
    });

    test('no age before birth', () {
      final birthday = Birthday(
        id: 'b',
        name: 'Bébé',
        month: 6,
        day: 1,
        birthYear: 2027,
        createdAt: created,
        updatedAt: created,
      );
      expect(birthday.occurrences(Day(2026, 1, 1), Day(2026, 12, 31)), isEmpty);
      expect(
        birthday.occurrences(Day(2027, 1, 1), Day(2027, 12, 31)).single.title,
        'Naissance de Bébé',
      );
    });
  });
}
