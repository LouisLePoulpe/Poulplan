import 'day.dart';

/// Days displayed by a month view: whole weeks covering the month of
/// [month], starting on [firstDayOfWeek] (ISO weekday, Monday = 1).
///
/// Always returns 6 weeks (42 days) so that the grid keeps a stable height
/// while navigating between months.
List<Day> monthGridDays(Day month, {required int firstDayOfWeek}) {
  assert(firstDayOfWeek >= 1 && firstDayOfWeek <= 7);
  final start = month.firstDayOfMonth.startOfWeek(firstDayOfWeek);
  return List.generate(42, start.addDays, growable: false);
}

/// Weekdays in display order, starting on [firstDayOfWeek].
List<int> orderedWeekdays(int firstDayOfWeek) =>
    List.generate(7, (i) => (firstDayOfWeek - 1 + i) % 7 + 1);
