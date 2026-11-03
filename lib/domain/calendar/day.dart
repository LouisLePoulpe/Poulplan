import 'package:meta/meta.dart';

/// A calendar date without time of day nor time zone.
///
/// Arithmetic goes through UTC so that daylight saving transitions never
/// shift a date (a local day can last 23 or 25 hours).
@immutable
class Day implements Comparable<Day> {
  /// Builds a normalized date: `Day(2026, 1, 32)` equals `Day(2026, 2, 1)`.
  factory Day(int year, int month, int day) {
    final utc = DateTime.utc(year, month, day);
    return Day._(utc.year, utc.month, utc.day);
  }

  const Day._(this.year, this.month, this.day);

  /// The date part of [dateTime], read in its own time zone (local or UTC).
  factory Day.fromDateTime(DateTime dateTime) =>
      Day._(dateTime.year, dateTime.month, dateTime.day);

  /// Today in the device's local time zone.
  factory Day.today() => Day.fromDateTime(DateTime.now());

  /// Parses `yyyy-MM-dd`.
  factory Day.parse(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) throw FormatException('Invalid date', iso);
    return Day(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  final int year;
  final int month;
  final int day;

  DateTime toUtcMidnight() => DateTime.utc(year, month, day);

  /// Local midnight; may not exist exactly on DST days, Dart then shifts it.
  DateTime toLocalMidnight() => DateTime(year, month, day);

  Day addDays(int days) => Day(year, month, day + days);

  Day addMonths(int months) {
    final target = Day(year, month + months, 1);
    final last = target.lastDayOfMonth.day;
    return Day(target.year, target.month, day > last ? last : day);
  }

  Day get firstDayOfMonth => Day._(year, month, 1);

  Day get lastDayOfMonth => Day(year, month + 1, 0);

  /// ISO weekday: Monday = 1 … Sunday = 7.
  int get weekday => toUtcMidnight().weekday;

  /// Number of days from [other] to this date (negative if [other] is later).
  int differenceInDays(Day other) =>
      toUtcMidnight().difference(other.toUtcMidnight()).inDays;

  /// First day of the week containing this date.
  Day startOfWeek(int firstDayOfWeek) =>
      addDays(-((weekday - firstDayOfWeek + 7) % 7));

  bool isBefore(Day other) => compareTo(other) < 0;

  bool isAfter(Day other) => compareTo(other) > 0;

  @override
  int compareTo(Day other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is Day &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}'
      '-${day.toString().padLeft(2, '0')}';
}
