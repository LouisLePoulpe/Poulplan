import '../calendar/day.dart';
import 'recurrence_rule.dart';

/// Rules of the two halves of a series cut at [splitDay] ("this occurrence
/// and the following ones"): [before] covers occurrences strictly before
/// [splitDay], [after] those from [splitDay] on (with [splitDay] as its new
/// start).
({RecurrenceRule before, RecurrenceRule after, bool beforeIsEmpty}) splitRule(
  RecurrenceRule rule,
  Day seriesStart,
  Day splitDay,
) {
  final earlier = splitDay.isAfter(seriesStart)
      ? rule
            .occurrenceDays(
              seriesStart,
              from: seriesStart,
              to: splitDay.addDays(-1),
            )
            .length
      : 0;
  if (rule.count != null) {
    final remaining = rule.count! - earlier;
    return (
      before: rule.copyWith(count: () => earlier == 0 ? 1 : earlier),
      after: rule.copyWith(count: () => remaining < 1 ? 1 : remaining),
      beforeIsEmpty: earlier == 0,
    );
  }
  return (
    before: rule.copyWith(until: () => splitDay.addDays(-1)),
    after: rule,
    beforeIsEmpty: earlier == 0,
  );
}
