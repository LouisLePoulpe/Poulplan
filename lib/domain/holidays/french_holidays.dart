import '../calendar/day.dart';
import '../entities/calendar_event.dart';

/// Easter Sunday (Gregorian calendar, anonymous algorithm).
Day easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return Day(year, month, day);
}

/// French public holidays of [year] (metropolitan France), with their names.
Map<Day, String> frenchPublicHolidays(int year, {bool alsaceMoselle = false}) {
  final easter = easterSunday(year);
  final holidays = {
    Day(year, 1, 1): "Jour de l'An",
    if (alsaceMoselle) easter.addDays(-2): 'Vendredi saint',
    easter.addDays(1): 'Lundi de Pâques',
    Day(year, 5, 1): 'Fête du Travail',
    Day(year, 5, 8): 'Victoire 1945',
    easter.addDays(39): 'Ascension',
    easter.addDays(50): 'Lundi de Pentecôte',
    Day(year, 7, 14): 'Fête nationale',
    Day(year, 8, 15): 'Assomption',
    Day(year, 11, 1): 'Toussaint',
    Day(year, 11, 11): 'Armistice 1918',
    Day(year, 12, 25): 'Noël',
    if (alsaceMoselle) Day(year, 12, 26): 'Saint-Étienne',
  };
  final sorted = holidays.keys.toList()..sort();
  return {for (final day in sorted) day: holidays[day]!};
}

/// Public holidays with a per-year cache.
class HolidayCalendar {
  HolidayCalendar({this.alsaceMoselle = false});

  /// Calendar without any holiday (holidays display turned off).
  HolidayCalendar.none() : alsaceMoselle = false, _disabled = true;

  final bool alsaceMoselle;
  bool _disabled = false;
  final _years = <int, Map<Day, String>>{};

  Map<Day, String> _year(int year) => _years.putIfAbsent(
    year,
    () => _disabled
        ? const {}
        : frenchPublicHolidays(year, alsaceMoselle: alsaceMoselle),
  );

  String? nameOf(Day day) => _year(day.year)[day];

  bool isHoliday(Day day) => nameOf(day) != null;

  bool isWorkingDay(Day day) =>
      day.weekday != DateTime.saturday &&
      day.weekday != DateTime.sunday &&
      !isHoliday(day);

  Day nextWorkingDay(Day day) {
    var d = day;
    while (!isWorkingDay(d)) {
      d = d.addDays(1);
    }
    return d;
  }

  Day previousWorkingDay(Day day) {
    var d = day;
    while (!isWorkingDay(d)) {
      d = d.addDays(-1);
    }
    return d;
  }

  /// Holidays between [from] and [to] inclusive.
  Map<Day, String> between(Day from, Day to) => {
    for (var year = from.year; year <= to.year; year++)
      for (final MapEntry(key: day, value: name) in _year(year).entries)
        if (!day.isBefore(from) && !day.isAfter(to)) day: name,
  };
}

/// Display event for the public holiday [name] on [day].
CalendarEvent holidayEvent(Day day, String name) => CalendarEvent(
  id: 'holiday:$day',
  title: name,
  allDay: true,
  busy: false,
  start: day.toUtcMidnight(),
  end: day.addDays(1).toUtcMidnight(),
  timeZone: 'UTC',
  kind: EventKind.holiday,
  createdAt: day.toUtcMidnight(),
  updatedAt: day.toUtcMidnight(),
);
