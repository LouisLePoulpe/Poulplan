import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/recurrence/recurrence_rule.dart';

void main() {
  List<Day> days(String rule, Day start, Day from, Day to) =>
      RecurrenceRule.parse(rule)
          .occurrenceDays(start, from: from, to: to)
          .toList();

  List<Day> list(List<(int, int, int)> ymd) => [
    for (final (y, m, d) in ymd) Day(y, m, d),
  ];

  group('parse and format', () {
    for (final text in [
      'FREQ=DAILY;INTERVAL=3',
      'FREQ=WEEKLY;BYDAY=MO,TH',
      'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;COUNT=10',
      'FREQ=MONTHLY;BYDAY=-1FR;UNTIL=20271231',
      'FREQ=MONTHLY;BYMONTHDAY=15',
      'FREQ=YEARLY;BYMONTH=11;BYDAY=4TH',
    ]) {
      test(text, () {
        expect(RecurrenceRule.parse(text).toString(), text);
      });
    }

    test('ignores order and unknown parts, accepts an RRULE: prefix', () {
      final rule = RecurrenceRule.parse('RRULE:BYDAY=TU;X-FOO=1;FREQ=WEEKLY');
      expect(rule.toString(), 'FREQ=WEEKLY;BYDAY=TU');
    });

    test('UNTIL may be a date-time', () {
      final rule = RecurrenceRule.parse('FREQ=DAILY;UNTIL=20261231T235959Z');
      expect(rule.until, Day(2026, 12, 31));
    });

    test('rejects invalid rules', () {
      expect(() => RecurrenceRule.parse('INTERVAL=2'), throwsFormatException);
      expect(
        () => RecurrenceRule.parse('FREQ=DAILY;INTERVAL=0'),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=XX'),
        throwsFormatException,
      );
    });
  });

  group('daily', () {
    test('every 3 days', () {
      expect(
        days(
          'FREQ=DAILY;INTERVAL=3',
          Day(2026, 3, 1),
          Day(2026, 3, 1),
          Day(2026, 3, 15),
        ),
        list([
          (2026, 3, 1),
          (2026, 3, 4),
          (2026, 3, 7),
          (2026, 3, 10),
          (2026, 3, 13),
        ]),
      );
    });

    test('every 3 days, window far from the start keeps the rhythm', () {
      expect(
        days(
          'FREQ=DAILY;INTERVAL=3',
          Day(2026, 3, 1),
          Day(2027, 3, 1),
          Day(2027, 3, 6),
        ),
        // 2026-03-01 + 3k: 365 days later is 2027-03-01 (+365 = 3*121+2).
        list([(2027, 3, 2), (2027, 3, 5)]),
      );
    });

    test('weekdays only', () {
      expect(
        days(
          'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR',
          Day(2026, 11, 5),
          Day(2026, 11, 5),
          Day(2026, 11, 10),
        ),
        list([(2026, 11, 5), (2026, 11, 6), (2026, 11, 9), (2026, 11, 10)]),
      );
    });
  });

  group('weekly', () {
    test('every Monday and Thursday', () {
      expect(
        days(
          'FREQ=WEEKLY;BYDAY=MO,TH',
          Day(2026, 11, 2),
          Day(2026, 11, 1),
          Day(2026, 11, 15),
        ),
        list([(2026, 11, 2), (2026, 11, 5), (2026, 11, 9), (2026, 11, 12)]),
      );
    });

    test('default weekday is the start weekday', () {
      expect(
        days(
          'FREQ=WEEKLY',
          Day(2026, 11, 4),
          Day(2026, 11, 1),
          Day(2026, 11, 20),
        ),
        list([(2026, 11, 4), (2026, 11, 11), (2026, 11, 18)]),
      );
    });

    test('every other week, weeks starting on Monday', () {
      // Starts Thursday 5 November: the weeks of 2, 16 and 30 November.
      expect(
        days(
          'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH',
          Day(2026, 11, 5),
          Day(2026, 11, 1),
          Day(2026, 12, 1),
        ),
        list([(2026, 11, 5), (2026, 11, 16), (2026, 11, 19), (2026, 11, 30)]),
      );
    });

    test('occurrences before the series start are excluded', () {
      // Monday 2 November is in the first week but before the start.
      expect(
        days(
          'FREQ=WEEKLY;BYDAY=MO,TH',
          Day(2026, 11, 3),
          Day(2026, 11, 1),
          Day(2026, 11, 9),
        ),
        list([(2026, 11, 5), (2026, 11, 9)]),
      );
    });
  });

  group('monthly', () {
    test('last Friday of the month', () {
      expect(
        days(
          'FREQ=MONTHLY;BYDAY=-1FR',
          Day(2026, 1, 30),
          Day(2026, 1, 1),
          Day(2026, 6, 30),
        ),
        list([
          (2026, 1, 30),
          (2026, 2, 27),
          (2026, 3, 27),
          (2026, 4, 24),
          (2026, 5, 29),
          (2026, 6, 26),
        ]),
      );
    });

    test('second Tuesday of the month', () {
      expect(
        days(
          'FREQ=MONTHLY;BYDAY=2TU',
          Day(2026, 1, 13),
          Day(2026, 1, 1),
          Day(2026, 4, 30),
        ),
        list([(2026, 1, 13), (2026, 2, 10), (2026, 3, 10), (2026, 4, 14)]),
      );
    });

    test('the 31st skips shorter months', () {
      expect(
        days(
          'FREQ=MONTHLY',
          Day(2026, 1, 31),
          Day(2026, 1, 1),
          Day(2026, 8, 31),
        ),
        list([
          (2026, 1, 31),
          (2026, 3, 31),
          (2026, 5, 31),
          (2026, 7, 31),
          (2026, 8, 31),
        ]),
      );
    });

    test('last day of the month with BYMONTHDAY=-1', () {
      expect(
        days(
          'FREQ=MONTHLY;BYMONTHDAY=-1',
          Day(2028, 1, 31),
          Day(2028, 1, 1),
          Day(2028, 4, 30),
        ),
        list([(2028, 1, 31), (2028, 2, 29), (2028, 3, 31), (2028, 4, 30)]),
      );
    });

    test('every 3 months', () {
      expect(
        days(
          'FREQ=MONTHLY;INTERVAL=3',
          Day(2026, 1, 15),
          Day(2026, 1, 1),
          Day(2026, 12, 31),
        ),
        list([(2026, 1, 15), (2026, 4, 15), (2026, 7, 15), (2026, 10, 15)]),
      );
    });
  });

  group('yearly', () {
    test('29 February only on leap years', () {
      expect(
        days(
          'FREQ=YEARLY',
          Day(2024, 2, 29),
          Day(2024, 1, 1),
          Day(2032, 12, 31),
        ),
        list([(2024, 2, 29), (2028, 2, 29), (2032, 2, 29)]),
      );
    });

    test('a fixed date every year', () {
      expect(
        days(
          'FREQ=YEARLY',
          Day(1990, 7, 14),
          Day(2026, 1, 1),
          Day(2027, 12, 31),
        ),
        list([(2026, 7, 14), (2027, 7, 14)]),
      );
    });

    test('fourth Thursday of November', () {
      expect(
        days(
          'FREQ=YEARLY;BYMONTH=11;BYDAY=4TH',
          Day(2026, 11, 26),
          Day(2026, 1, 1),
          Day(2028, 12, 31),
        ),
        list([(2026, 11, 26), (2027, 11, 25), (2028, 11, 23)]),
      );
    });
  });

  group('limits', () {
    test('COUNT counts from the series start, not from the window', () {
      expect(
        days(
          'FREQ=DAILY;COUNT=5',
          Day(2026, 3, 1),
          Day(2026, 3, 4),
          Day(2026, 3, 31),
        ),
        list([(2026, 3, 4), (2026, 3, 5)]),
      );
    });

    test('COUNT with a filtered weekly rule', () {
      expect(
        days(
          'FREQ=WEEKLY;BYDAY=MO,TH;COUNT=3',
          Day(2026, 11, 2),
          Day(2026, 1, 1),
          Day(2027, 1, 1),
        ),
        list([(2026, 11, 2), (2026, 11, 5), (2026, 11, 9)]),
      );
    });

    test('UNTIL is inclusive', () {
      expect(
        days(
          'FREQ=DAILY;UNTIL=20260303',
          Day(2026, 3, 1),
          Day(2026, 1, 1),
          Day(2026, 12, 31),
        ),
        list([(2026, 3, 1), (2026, 3, 2), (2026, 3, 3)]),
      );
    });

    test('lastDay is known for bounded rules only', () {
      expect(
        RecurrenceRule.parse('FREQ=DAILY;COUNT=5').lastDay(Day(2026, 3, 1)),
        Day(2026, 3, 5),
      );
      expect(
        RecurrenceRule.parse('FREQ=WEEKLY;UNTIL=20261231')
            .lastDay(Day(2026, 3, 1)),
        Day(2026, 12, 31),
      );
      expect(
        RecurrenceRule.parse('FREQ=WEEKLY').lastDay(Day(2026, 3, 1)),
        isNull,
      );
    });

    test('a window decades after the start stays fast', () {
      final watch = Stopwatch()..start();
      final result = days(
        'FREQ=DAILY',
        Day(1970, 1, 1),
        Day(2100, 1, 1),
        Day(2100, 1, 7),
      );
      expect(result, hasLength(7));
      expect(watch.elapsedMilliseconds, lessThan(200));
    });
  });
}
