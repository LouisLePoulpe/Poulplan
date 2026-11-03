import 'package:intl/intl.dart';

import '../../../domain/calendar/day.dart';
import '../../../domain/recurrence/recurrence_rule.dart';

String _weekdayName(int weekday, String locale) =>
    // 5 January 2026 is a Monday.
    DateFormat.EEEE(locale).format(DateTime(2026, 1, 4 + weekday));

String _ordinal(int n) => n == 1 ? '1er' : '${n}e';

String _position(ByDay b, String locale) {
  final name = _weekdayName(b.weekday, locale);
  final position = b.position;
  if (position == null) return name;
  if (position == -1) return 'dernier $name';
  if (position < 0) return '${_ordinal(-position)} $name avant la fin';
  return '${_ordinal(position)} $name';
}

String _joinFr(List<String> items) => items.length <= 1
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} et ${items.last}';

/// Human-readable French description of [rule] for a series starting on
/// [start] (e.g. « Toutes les 2 semaines le lundi et le jeudi »).
String describeRule(RecurrenceRule rule, Day start, String locale) {
  final n = rule.interval;
  final text = StringBuffer();
  switch (rule.frequency) {
    case Frequency.daily:
      final weekdays = rule.byDay.map((b) => b.weekday).toSet();
      if (n == 1 &&
          weekdays.length == 5 &&
          !weekdays.contains(6) &&
          !weekdays.contains(7)) {
        text.write('Tous les jours de semaine');
      } else {
        text.write(n == 1 ? 'Tous les jours' : 'Tous les $n jours');
      }
    case Frequency.weekly:
      final weekdays = rule.byDay.isEmpty
          ? [start.weekday]
          : (rule.byDay.map((b) => b.weekday).toSet().toList()..sort());
      text
        ..write(n == 1 ? 'Toutes les semaines' : 'Toutes les $n semaines')
        ..write(' ')
        ..write(
          _joinFr([for (final w in weekdays) 'le ${_weekdayName(w, locale)}']),
        );
    case Frequency.monthly:
      text
        ..write(n == 1 ? 'Tous les mois' : 'Tous les $n mois')
        ..write(' le ')
        ..write(_monthDays(rule, start, locale));
    case Frequency.yearly:
      text.write(n == 1 ? 'Tous les ans' : 'Tous les $n ans');
      final month = rule.byMonth.isEmpty ? start.month : rule.byMonth.first;
      final monthName = DateFormat.MMMM(locale).format(DateTime(2026, month));
      if (rule.byDay.isNotEmpty) {
        final de = RegExp('^[aeiouy]').hasMatch(monthName) ? "d'" : 'de ';
        text.write(' le ${_position(rule.byDay.first, locale)} $de$monthName');
      } else {
        final day = rule.byMonthDay.isEmpty ? start.day : rule.byMonthDay.first;
        text.write(' le ${day == 1 ? '1er' : day} $monthName');
      }
  }
  if (rule.count != null) text.write(', ${rule.count} fois');
  if (rule.until != null) {
    text.write(
      ", jusqu'au ${DateFormat.yMMMd(locale).format(rule.until!.toLocalMidnight())}",
    );
  }
  return text.toString();
}

String _monthDays(RecurrenceRule rule, Day start, String locale) {
  if (rule.byDay.isNotEmpty) {
    return _joinFr([for (final b in rule.byDay) _position(b, locale)]);
  }
  final days = rule.byMonthDay.isEmpty ? [start.day] : rule.byMonthDay;
  return _joinFr([
    for (final d in days)
      d == -1
          ? 'dernier jour'
          : d < 0
          ? '${_ordinal(-d)} jour avant la fin'
          : '$d',
  ]);
}

/// Monthly rule on the same weekday position as [start] (« le 2e mardi »).
RecurrenceRule monthlyByPosition(Day start) => RecurrenceRule(
  frequency: Frequency.monthly,
  byDay: [ByDay(start.weekday, (start.day - 1) ~/ 7 + 1)],
);

/// Monthly rule « le dernier lundi » (etc.), only when [start] is the last such
/// weekday of its month.
RecurrenceRule? monthlyByLastWeekday(Day start) =>
    start.addDays(7).month != start.month
    ? RecurrenceRule(
        frequency: Frequency.monthly,
        byDay: [ByDay(start.weekday, -1)],
      )
    : null;
