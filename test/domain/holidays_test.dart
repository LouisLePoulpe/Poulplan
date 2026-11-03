import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/holidays/french_holidays.dart';

void main() {
  test('Easter Sunday', () {
    expect(easterSunday(2025), Day(2025, 4, 20));
    expect(easterSunday(2026), Day(2026, 4, 5));
    expect(easterSunday(2027), Day(2027, 3, 28));
    expect(easterSunday(2038), Day(2038, 4, 25));
    expect(easterSunday(2285), Day(2285, 3, 22));
  });

  test('French public holidays 2026', () {
    final holidays = frenchPublicHolidays(2026);
    expect(holidays, {
      Day(2026, 1, 1): "Jour de l'An",
      Day(2026, 4, 6): 'Lundi de Pâques',
      Day(2026, 5, 1): 'Fête du Travail',
      Day(2026, 5, 8): 'Victoire 1945',
      Day(2026, 5, 14): 'Ascension',
      Day(2026, 5, 25): 'Lundi de Pentecôte',
      Day(2026, 7, 14): 'Fête nationale',
      Day(2026, 8, 15): 'Assomption',
      Day(2026, 11, 1): 'Toussaint',
      Day(2026, 11, 11): 'Armistice 1918',
      Day(2026, 12, 25): 'Noël',
    });
  });

  test('Alsace-Moselle adds Good Friday and Saint Stephen', () {
    final holidays = frenchPublicHolidays(2026, alsaceMoselle: true);
    expect(holidays[Day(2026, 4, 3)], 'Vendredi saint');
    expect(holidays[Day(2026, 12, 26)], 'Saint-Étienne');
    expect(holidays, hasLength(13));
  });

  test('HolidayCalendar caches years and answers ranges', () {
    final calendar = HolidayCalendar();
    expect(calendar.isHoliday(Day(2027, 3, 29)), isTrue); // Easter Monday
    expect(calendar.isHoliday(Day(2027, 3, 30)), isFalse);
    final range = calendar.between(Day(2026, 12, 20), Day(2027, 1, 5));
    expect(range.keys, [Day(2026, 12, 25), Day(2027, 1, 1)]);
  });

  test('working days skip weekends and holidays', () {
    final calendar = HolidayCalendar();
    // Friday 1 May 2026 is a holiday: next working day is Monday 4 May.
    expect(calendar.nextWorkingDay(Day(2026, 5, 1)), Day(2026, 5, 4));
    // Monday 25 May 2026 (Pentecost Monday): previous is Friday 22 May.
    expect(calendar.previousWorkingDay(Day(2026, 5, 25)), Day(2026, 5, 22));
    expect(calendar.nextWorkingDay(Day(2026, 5, 5)), Day(2026, 5, 5));
  });
}
