import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/time/device_time_zone.dart';
import '../../../data/providers.dart';
import '../../../domain/calendar/day.dart';
import '../../../domain/calendar/month_grid.dart';
import '../../../domain/entities/calendar_event.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/calendar_providers.dart';
import 'demo_events.dart';

class MonthViewPage extends ConsumerWidget {
  const MonthViewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final month = ref.watch(visibleMonthProvider);
    final notifier = ref.read(visibleMonthProvider.notifier);
    final title = toBeginningOfSentenceCase(
      DateFormat.yMMMM(locale).format(month.toLocalMidnight()),
      locale,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): notifier.previous,
        const SingleActivator(LogicalKeyboardKey.pageUp): notifier.previous,
        const SingleActivator(LogicalKeyboardKey.arrowRight): notifier.next,
        const SingleActivator(LogicalKeyboardKey.pageDown): notifier.next,
        const SingleActivator(LogicalKeyboardKey.keyT): notifier.goToToday,
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            context.push(Routes.settings),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 4,
            title: Row(
              children: [
                IconButton(
                  tooltip: l10n.previousMonth,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: notifier.previous,
                ),
                Flexible(
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(title)),
                ),
                IconButton(
                  tooltip: l10n.nextMonth,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: notifier.next,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: l10n.today,
                icon: const Icon(Icons.today),
                onPressed: notifier.goToToday,
              ),
              IconButton(
                tooltip: l10n.settings,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(Routes.settings),
              ),
              if (kDebugMode) const _DebugMenu(),
            ],
          ),
          body: GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 300) notifier.previous();
              if (velocity < -300) notifier.next();
            },
            child: const _MonthGrid(),
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(monthGridProvider);
    final month = ref.watch(visibleMonthProvider);
    final today = ref.watch(todayProvider);
    final firstDay = ref.watch(
      settingsProvider.select((s) => s.firstDayOfWeek),
    );
    final eventsByDay = ref.watch(monthEventsProvider).value ?? const {};
    final locale = Localizations.localeOf(context).toString();
    final weekdayFormat = DateFormat.E(locale);
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            for (final weekday in orderedWeekdays(firstDay))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    // 5 January 2026 is a Monday.
                    weekdayFormat.format(DateTime(2026, 1, 4 + weekday)),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: Column(
            children: [
              for (var week = 0; week < days.length ~/ 7; week++)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final day in days.skip(week * 7).take(7))
                        Expanded(
                          child: _DayCell(
                            day: day,
                            inMonth: day.month == month.month,
                            isToday: day == today,
                            events: eventsByDay[day] ?? const [],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.events,
  });

  static const _chipHeight = 18.0;
  static const _headerHeight = 26.0;

  final Day day;
  final bool inMonth;
  final bool isToday;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final categoryColors = ref.watch(categoryColorsProvider);

    return Semantics(
      label: DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString())
          .format(day.toLocalMidnight()),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: inMonth ? null : scheme.surfaceContainerLow,
          border: Border(
            right: BorderSide(color: theme.dividerColor, width: 0.5),
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxHeight - _headerHeight;
            var maxChips = (available / _chipHeight).floor().clamp(0, 99);
            final overflow = events.length > maxChips;
            if (overflow) maxChips = (maxChips - 1).clamp(0, 99);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _headerHeight,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: isToday
                          ? BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isToday
                              ? scheme.onPrimary
                              : inMonth
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontWeight: isToday ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final event in events.take(maxChips))
                  _EventChip(
                    event: event,
                    color: Color(
                      event.color ??
                          categoryColors[event.categoryId] ??
                          scheme.primary.toARGB32(),
                    ),
                  ),
                if (overflow)
                  SizedBox(
                    height: _chipHeight,
                    child: Text(
                      l10n.moreEvents(events.length - maxChips),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.event, required this.color});

  final CalendarEvent event;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Container(
      height: _DayCell._chipHeight - 2,
      margin: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: event.allDay ? color : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: event.allDay
            ? null
            : Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: event.allDay ? onColor : null),
      ),
    );
  }
}

class _DebugMenu extends ConsumerWidget {
  const _DebugMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<void>(
      itemBuilder: (context) => [
        PopupMenuItem(
          child: Text(l10n.debugInsertDemo),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            await insertDemoEvents(
              ref.read(eventRepositoryProvider),
              ref.read(todayProvider),
              ref.read(deviceTimeZoneProvider),
            );
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.debugDemoInserted)),
            );
          },
        ),
      ],
    );
  }
}
