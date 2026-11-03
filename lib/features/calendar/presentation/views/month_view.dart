import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/formatters.dart';
import '../../../../data/providers.dart';
import '../../../../domain/calendar/day.dart';
import '../../../../domain/calendar/day_layout.dart';
import '../../../../domain/calendar/event_timing.dart';
import '../../../../domain/calendar/month_grid.dart';
import '../../../../domain/entities/calendar_event.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../event_editor/presentation/quick_create.dart';
import '../../providers/calendar_providers.dart';
import '../event_actions.dart';
import '../widgets/event_drag_source.dart';
import '../widgets/event_style.dart';
import '../widgets/grid_lines.dart';

class MonthView extends ConsumerWidget {
  const MonthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(monthGridProvider);
    final month = ref.watch(focusedDayProvider.select((d) => d.month));
    final today = ref.watch(todayProvider);
    final firstDay = ref.watch(
      settingsProvider.select((s) => s.firstDayOfWeek),
    );
    final eventsByDay =
        ref
            .watch(eventsByDayProvider((first: days.first, last: days.last)))
            .value ??
        const {};
    final weekdayFormat = DateFormat.E(localeOf(context));
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
          child: Stack(
            children: [
              Column(
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
                                inMonth: day.month == month,
                                isToday: day == today,
                                events: eventsByDay[day] ?? const [],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GridLinesPainter(
                      columns: 7,
                      rows: days.length ~/ 7,
                      color: theme.dividerColor,
                      pixelRatio: MediaQuery.devicePixelRatioOf(context),
                    ),
                  ),
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

  static const chipHeight = 18.0;
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
    final overlapping = overlappingEventIds(events);

    return DragTarget<CalendarEvent>(
      onAcceptWithDetails: (details) => saveMovedEvent(
        context,
        ref,
        moveToDay(
          details.data,
          day,
          display: ref.read(displayLocationProvider),
        ),
      ),
      builder: (context, candidates, rejected) => Semantics(
        button: true,
        label: formatDayLong(context, day),
        child: GestureDetector(
          onSecondaryTap: () => showQuickCreate(context, ref, day: day),
          child: InkWell(
            onTap: () {
              ref.read(focusedDayProvider.notifier).set(day);
              ref
                  .read(calendarViewProvider.notifier)
                  .select(CalendarViewType.day);
            },
            onLongPress: () => showQuickCreate(context, ref, day: day),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: candidates.isNotEmpty
                    ? scheme.primaryContainer.withValues(alpha: 0.5)
                    : inMonth
                    ? null
                    : scheme.surfaceContainerLow,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final available = constraints.maxHeight - _headerHeight;
                  var maxChips = (available / chipHeight).floor().clamp(0, 99);
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
                                    : scheme.onSurfaceVariant.withValues(
                                        alpha: 0.6,
                                      ),
                                fontWeight: isToday ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final event in events.take(maxChips))
                        MonthEventChip(
                          event: event,
                          overlapping: overlapping.contains(event.id),
                        ),
                      if (overflow)
                        SizedBox(
                          height: chipHeight,
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
          ),
        ),
      ),
    );
  }
}

/// Compact one-line event, used by the month view and all-day rows.
class MonthEventChip extends ConsumerWidget {
  const MonthEventChip({
    super.key,
    required this.event,
    this.overlapping = false,
  });

  final CalendarEvent event;
  final bool overlapping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = eventColor(ref, context, event);
    final chip = _ChipBody(
      event: event,
      color: color,
      overlapping: overlapping,
    );
    return GestureDetector(
      onTap: () => openEvent(context, event),
      onSecondaryTapUp: (details) =>
          showEventMenu(context, ref, event, details.globalPosition),
      child: EventDragSource(
        event: event,
        feedback: SizedBox(width: 140, child: chip),
        child: chip,
      ),
    );
  }
}

class _ChipBody extends StatelessWidget {
  const _ChipBody({
    required this.event,
    required this.color,
    required this.overlapping,
  });

  final CalendarEvent event;
  final Color color;
  final bool overlapping;

  @override
  Widget build(BuildContext context) {
    final onColor = foregroundOn(color);
    final textStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: event.allDay ? onColor : null);
    return Container(
      height: _DayCell.chipHeight - 2,
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
      child: Row(
        children: [
          if (overlapping || eventIcon(event) != null)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                overlapping ? Icons.warning_amber_rounded : eventIcon(event),
                size: 11,
                color: textStyle?.color,
                semanticLabel: overlapping
                    ? AppLocalizations.of(context).overlapWarning
                    : null,
              ),
            ),
          Expanded(
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}
