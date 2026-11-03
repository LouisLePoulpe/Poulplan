import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/calendar/month_grid.dart';

void main() {
  group('Day', () {
    test('normalizes overflowing values', () {
      expect(Day(2026, 1, 32), Day(2026, 2, 1));
      expect(Day(2026, 3, 0), Day(2026, 2, 28));
      expect(Day(2024, 3, 0), Day(2024, 2, 29));
    });

    test('adds days across a DST change without drifting', () {
      expect(Day(2026, 3, 28).addDays(2), Day(2026, 3, 30));
      expect(Day(2026, 10, 24).addDays(2), Day(2026, 10, 26));
    });

    test('addMonths clamps to the end of the month', () {
      expect(Day(2026, 1, 31).addMonths(1), Day(2026, 2, 28));
      expect(Day(2024, 1, 31).addMonths(1), Day(2024, 2, 29));
      expect(Day(2026, 12, 15).addMonths(1), Day(2027, 1, 15));
      expect(Day(2026, 1, 15).addMonths(-1), Day(2025, 12, 15));
    });

    test('weekday and start of week', () {
      final d = Day(2026, 11, 3); // Tuesday
      expect(d.weekday, DateTime.tuesday);
      expect(d.startOfWeek(DateTime.monday), Day(2026, 11, 2));
      expect(d.startOfWeek(DateTime.sunday), Day(2026, 11, 1));
      expect(d.startOfWeek(DateTime.tuesday), d);
    });

    test('parse and toString round-trip', () {
      expect(Day.parse('2026-02-09'), Day(2026, 2, 9));
      expect(Day(2026, 2, 9).toString(), '2026-02-09');
    });

    test('differenceInDays', () {
      expect(Day(2026, 3, 30).differenceInDays(Day(2026, 3, 28)), 2);
      expect(Day(2026, 1, 1).differenceInDays(Day(2027, 1, 1)), -365);
    });
  });

  group('monthGridDays', () {
    test('starts on the configured first day of week', () {
      final days = monthGridDays(
        Day(2026, 11, 1),
        firstDayOfWeek: DateTime.monday,
      );
      expect(days, hasLength(42));
      // 1 November 2026 is a Sunday: the grid starts Monday 26 October.
      expect(days.first, Day(2026, 10, 26));
      expect(days.last, Day(2026, 12, 6));
    });

    test('Sunday-first grid', () {
      final days = monthGridDays(
        Day(2026, 11, 1),
        firstDayOfWeek: DateTime.sunday,
      );
      expect(days.first, Day(2026, 11, 1));
    });

    test('every day of the month is in the grid', () {
      for (var m = 1; m <= 12; m++) {
        final month = Day(2026, m, 1);
        final days = monthGridDays(month, firstDayOfWeek: DateTime.monday);
        expect(days, contains(month));
        expect(days, contains(month.lastDayOfMonth));
      }
    });

    test('orderedWeekdays', () {
      expect(orderedWeekdays(DateTime.monday), [1, 2, 3, 4, 5, 6, 7]);
      expect(orderedWeekdays(DateTime.sunday), [7, 1, 2, 3, 4, 5, 6]);
    });
  });
}
