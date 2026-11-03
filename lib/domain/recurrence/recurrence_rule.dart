import 'package:meta/meta.dart';

import '../calendar/day.dart';

enum Frequency { daily, weekly, monthly, yearly }

/// A `BYDAY` entry: a weekday, optionally with its position in the month
/// (`2TU` = second Tuesday, `-1FR` = last Friday).
@immutable
class ByDay {
  const ByDay(this.weekday, [this.position]);

  /// ISO weekday, Monday = 1.
  final int weekday;

  /// 1…5 from the start of the month, -1…-5 from its end; null = every.
  final int? position;

  static const _codes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  static ByDay parse(String text) {
    final match = RegExp(r'^([+-]?\d{1,2})?([A-Z]{2})$').firstMatch(text);
    final weekday = match == null ? -1 : _codes.indexOf(match.group(2)!);
    final position = match?.group(1) == null
        ? null
        : int.parse(match!.group(1)!);
    if (weekday < 0 || position == 0 || (position?.abs() ?? 0) > 5) {
      throw FormatException('Invalid BYDAY', text);
    }
    return ByDay(weekday + 1, position);
  }

  @override
  String toString() => '${position ?? ''}${_codes[weekday - 1]}';

  @override
  bool operator ==(Object other) =>
      other is ByDay && other.weekday == weekday && other.position == position;

  @override
  int get hashCode => Object.hash(weekday, position);
}

/// Subset of the iCalendar RRULE (RFC 5545) used by Poulplan.
///
/// Dates are computed in the series' own calendar (floating days); times and
/// time zones are applied by the caller. As in RFC 5545, invalid dates (31
/// April, 29 February of a common year) are skipped, not moved.
@immutable
class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.byDay = const [],
    this.byMonthDay = const [],
    this.byMonth = const [],
    this.count,
    this.until,
  });

  factory RecurrenceRule.parse(String text) {
    final parts = <String, String>{};
    final body = text.trim().replaceFirst(RegExp('^RRULE:'), '');
    for (final part in body.split(';')) {
      if (part.isEmpty) continue;
      final eq = part.indexOf('=');
      if (eq <= 0) throw FormatException('Invalid RRULE part', part);
      parts[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1);
    }
    final frequency = switch (parts['FREQ']) {
      'DAILY' => Frequency.daily,
      'WEEKLY' => Frequency.weekly,
      'MONTHLY' => Frequency.monthly,
      'YEARLY' => Frequency.yearly,
      _ => throw FormatException('Missing or unsupported FREQ', text),
    };
    List<int> ints(String? value, int min, int max) => [
      for (final v in (value ?? '').split(',').where((v) => v.isNotEmpty))
        _checkedInt(v, min, max),
    ];
    final interval = parts['INTERVAL'] == null
        ? 1
        : _checkedInt(parts['INTERVAL']!, 1, 1000);
    final until = parts['UNTIL'];
    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      byDay: [
        for (final v
            in (parts['BYDAY'] ?? '').split(',').where((v) => v.isNotEmpty))
          ByDay.parse(v),
      ],
      byMonthDay: ints(parts['BYMONTHDAY'], -31, 31)..remove(0),
      byMonth: ints(parts['BYMONTH'], 1, 12),
      count: parts['COUNT'] == null
          ? null
          : _checkedInt(parts['COUNT']!, 1, 100000),
      until: until == null ? null : _parseDate(until),
    );
  }

  final Frequency frequency;
  final int interval;
  final List<ByDay> byDay;
  final List<int> byMonthDay;
  final List<int> byMonth;
  final int? count;

  /// Last allowed day, inclusive.
  final Day? until;

  bool get isBounded => count != null || until != null;

  RecurrenceRule copyWith({int? Function()? count, Day? Function()? until}) =>
      RecurrenceRule(
        frequency: frequency,
        interval: interval,
        byDay: byDay,
        byMonthDay: byMonthDay,
        byMonth: byMonth,
        count: count != null ? count() : this.count,
        until: until != null ? until() : this.until,
      );

  /// Occurrence days of a series starting on [start], within [from]…[to]
  /// (inclusive), in chronological order.
  Iterable<Day> occurrenceDays(
    Day start, {
    required Day from,
    required Day to,
  }) sync* {
    var produced = 0;
    var period = count == null ? _skipPeriods(start, from) : 0;
    while (true) {
      final periodStart = _periodStart(start, period);
      if (periodStart.isAfter(to)) return;
      if (until != null && periodStart.isAfter(until!)) return;
      for (final day in _candidates(start, periodStart)) {
        if (day.isBefore(start)) continue;
        if (until != null && day.isAfter(until!)) return;
        if (count != null && produced >= count!) return;
        produced++;
        if (day.isAfter(to)) return;
        if (!day.isBefore(from)) yield day;
      }
      period++;
    }
  }

  /// Day of the last occurrence, or null for an endless series.
  Day? lastDay(Day start) {
    if (until != null) return until;
    if (count == null) return null;
    Day? last;
    for (final day in occurrenceDays(
      start,
      from: start,
      to: Day(9999, 12, 31),
    )) {
      last = day;
    }
    return last;
  }

  /// Whether [day] is an occurrence of a series starting on [start].
  bool occursOn(Day start, Day day) =>
      occurrenceDays(start, from: day, to: day).isNotEmpty;

  // Index of a period a little before [from], so that long-running series
  // without COUNT do not iterate from their start.
  int _skipPeriods(Day start, Day from) {
    if (!from.isAfter(start)) return 0;
    final elapsed = switch (frequency) {
      Frequency.daily => from.differenceInDays(start),
      Frequency.weekly =>
        from
                .startOfWeek(DateTime.monday)
                .differenceInDays(start.startOfWeek(DateTime.monday)) ~/
            7,
      Frequency.monthly =>
        (from.year - start.year) * 12 + from.month - start.month,
      Frequency.yearly => from.year - start.year,
    };
    return (elapsed ~/ interval - 1).clamp(0, 1 << 30);
  }

  Day _periodStart(Day start, int period) {
    final n = period * interval;
    return switch (frequency) {
      Frequency.daily => start.addDays(n),
      Frequency.weekly => start.startOfWeek(DateTime.monday).addDays(7 * n),
      Frequency.monthly => Day(start.year, start.month + n, 1),
      Frequency.yearly => Day(start.year + n, 1, 1),
    };
  }

  List<Day> _candidates(Day start, Day periodStart) {
    switch (frequency) {
      case Frequency.daily:
        if (byDay.isNotEmpty &&
            !byDay.any((b) => b.weekday == periodStart.weekday)) {
          return const [];
        }
        if (byMonth.isNotEmpty && !byMonth.contains(periodStart.month)) {
          return const [];
        }
        return [periodStart];
      case Frequency.weekly:
        final weekdays = byDay.isEmpty
            ? [start.weekday]
            : (byDay.map((b) => b.weekday).toSet().toList()..sort());
        return [for (final w in weekdays) periodStart.addDays(w - 1)];
      case Frequency.monthly:
        if (byMonth.isNotEmpty && !byMonth.contains(periodStart.month)) {
          return const [];
        }
        return _daysInMonth(start, periodStart.year, periodStart.month);
      case Frequency.yearly:
        final months = byMonth.isEmpty
            ? [start.month]
            : (byMonth.toList()..sort());
        return [
          for (final m in months) ..._daysInMonth(start, periodStart.year, m),
        ];
    }
  }

  List<Day> _daysInMonth(Day start, int year, int month) {
    final length = Day(year, month + 1, 0).day;
    final days = <int>{};
    if (byMonthDay.isNotEmpty) {
      for (final d in byMonthDay) {
        final value = d > 0 ? d : length + d + 1;
        if (value >= 1 && value <= length) days.add(value);
      }
    } else if (byDay.isNotEmpty) {
      for (final b in byDay) {
        final first = Day(year, month, 1);
        final offset = (b.weekday - first.weekday + 7) % 7;
        final matches = [for (var d = 1 + offset; d <= length; d += 7) d];
        final position = b.position;
        if (position == null) {
          days.addAll(matches);
        } else {
          final index = position > 0 ? position - 1 : matches.length + position;
          if (index >= 0 && index < matches.length) days.add(matches[index]);
        }
      }
    } else if (start.day <= length) {
      days.add(start.day);
    }
    return [for (final d in days.toList()..sort()) Day(year, month, d)];
  }

  @override
  String toString() {
    final parts = [
      'FREQ=${frequency.name.toUpperCase()}',
      if (interval != 1) 'INTERVAL=$interval',
      if (byMonth.isNotEmpty) 'BYMONTH=${byMonth.join(',')}',
      if (byMonthDay.isNotEmpty) 'BYMONTHDAY=${byMonthDay.join(',')}',
      if (byDay.isNotEmpty) 'BYDAY=${byDay.join(',')}',
      if (count != null) 'COUNT=$count',
      if (until != null) 'UNTIL=${until.toString().replaceAll('-', '')}',
    ];
    return parts.join(';');
  }

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  static int _checkedInt(String text, int min, int max) {
    final value = int.tryParse(text);
    if (value == null || value < min || value > max) {
      throw FormatException('Out of range', text);
    }
    return value;
  }

  static Day _parseDate(String text) {
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(text);
    if (match == null) throw FormatException('Invalid UNTIL', text);
    return Day(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}
