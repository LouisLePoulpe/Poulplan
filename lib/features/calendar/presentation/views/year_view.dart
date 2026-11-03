import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/formatters.dart';
import '../../../../data/providers.dart';
import '../../../../domain/calendar/day.dart';
import '../../../../domain/calendar/month_grid.dart';
import '../../providers/calendar_providers.dart';

class YearView extends ConsumerWidget {
  const YearView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(focusedDayProvider.select((d) => d.year));
    final busyDays =
        ref
            .watch(
              eventsByDayProvider((
                first: Day(year, 1, 1),
                last: Day(year, 12, 31),
              )),
            )
            .value
            ?.keys
            .toSet() ??
        const <Day>{};

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 260).floor().clamp(1, 4);
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
          ),
          itemCount: 12,
          itemBuilder: (context, i) =>
              _MiniMonth(month: Day(year, i + 1, 1), busyDays: busyDays),
        );
      },
    );
  }
}

class _MiniMonth extends ConsumerWidget {
  const _MiniMonth({required this.month, required this.busyDays});

  final Day month;
  final Set<Day> busyDays;

  void _open(WidgetRef ref, Day day, CalendarViewType view) {
    ref.read(focusedDayProvider.notifier).set(day);
    ref.read(calendarViewProvider.notifier).select(view);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = localeOf(context);
    final firstDay = ref.watch(
      settingsProvider.select((s) => s.firstDayOfWeek),
    );
    final today = ref.watch(todayProvider);
    final days = monthGridDays(month, firstDayOfWeek: firstDay);
    final narrow = DateFormat.EEEEE(locale);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            InkWell(
              onTap: () => _open(ref, month, CalendarViewType.month),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  toBeginningOfSentenceCase(
                    DateFormat.MMMM(locale).format(month.toLocalMidnight()),
                    locale,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final w in orderedWeekdays(firstDay))
                  Expanded(
                    child: Text(
                      narrow.format(DateTime(2026, 1, 4 + w)).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Column(
                children: [
                  for (var week = 0; week < 6; week++)
                    Expanded(
                      child: Row(
                        children: [
                          for (final day in days.skip(week * 7).take(7))
                            Expanded(
                              child: day.month != month.month
                                  ? const SizedBox()
                                  : _MiniDay(
                                      day: day,
                                      isToday: day == today,
                                      busy: busyDays.contains(day),
                                      onTap: () =>
                                          _open(ref, day, CalendarViewType.day),
                                    ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniDay extends StatelessWidget {
  const _MiniDay({
    required this.day,
    required this.isToday,
    required this.busy,
    required this.onTap,
  });

  final Day day;
  final bool isToday;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        alignment: Alignment.center,
        decoration: isToday
            ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${day.day}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isToday ? scheme.onPrimary : null,
                fontWeight: busy ? FontWeight.bold : null,
              ),
            ),
            if (busy)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isToday ? scheme.onPrimary : scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
