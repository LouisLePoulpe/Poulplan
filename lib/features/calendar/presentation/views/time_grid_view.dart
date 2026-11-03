import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/formatters.dart';
import '../../../../domain/calendar/day.dart';
import '../../../../domain/calendar/day_layout.dart';
import '../../../../domain/calendar/event_timing.dart';
import '../../../../domain/calendar/week_lanes.dart';
import '../../../../domain/entities/calendar_event.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../event_editor/presentation/quick_create.dart';
import '../../providers/calendar_providers.dart';
import '../event_actions.dart';
import '../widgets/event_drag_source.dart';
import '../widgets/event_style.dart';
import '../widgets/grid_lines.dart';
import 'month_view.dart' show MonthEventChip;

const _hourHeight = 52.0;
const _gutterWidth = 52.0;
const _allDayRowMaxChips = 3;

/// Day (1 column) and week (7 columns) views on a 24 h time grid.
class TimeGridView extends ConsumerStatefulWidget {
  const TimeGridView({super.key, required this.dayCount});

  final int dayCount;

  @override
  ConsumerState<TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends ConsumerState<TimeGridView> {
  final _scroll = ScrollController(initialScrollOffset: 7 * _hourHeight);
  Timer? _clock;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.dayCount == 1
        ? ref.watch(focusedDayProvider)
        : ref.watch(weekStartProvider);
    final days = List.generate(widget.dayCount, first.addDays);
    final eventsByDay =
        ref
            .watch(eventsByDayProvider((first: days.first, last: days.last)))
            .value ??
        const {};
    final today = ref.watch(todayProvider);
    final toLocal = ref.watch(localTimeProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        _Header(days: days, today: today),
        _AllDayRow(days: days, eventsByDay: eventsByDay),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: 24 * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _gutterWidth,
                    child: Stack(
                      children: [
                        for (var h = 1; h < 24; h++)
                          Positioned(
                            top: h * _hourHeight - 8,
                            right: 6,
                            child: Text(
                              formatMinutes(h * 60),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final day in days)
                    Expanded(
                      child: _DayColumn(
                        day: day,
                        events: (eventsByDay[day] ?? const [])
                            .where((e) => !e.allDay)
                            .toList(),
                        nowMinute: day == today
                            ? () {
                                final local = toLocal(_now);
                                return local.hour * 60 + local.minute;
                              }()
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.days, required this.today});

  final List<Day> days;
  final Day today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weekday = DateFormat.E(localeOf(context));
    return Row(
      children: [
        const SizedBox(width: _gutterWidth),
        for (final day in days)
          Expanded(
            child: InkWell(
              onTap: days.length == 1
                  ? null
                  : () {
                      ref.read(focusedDayProvider.notifier).set(day);
                      ref
                          .read(calendarViewProvider.notifier)
                          .select(CalendarViewType.day);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Text(
                      weekday.format(day.toLocalMidnight()),
                      style: theme.textTheme.labelSmall,
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: day == today
                          ? BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: day == today ? scheme.onPrimary : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// All-day events (and drop zone to move events by whole days); multi-day
/// ones are drawn as continuous bars over the columns.
class _AllDayRow extends ConsumerWidget {
  const _AllDayRow({required this.days, required this.eventsByDay});

  final List<Day> days;
  final Map<Day, List<CalendarEvent>> eventsByDay;

  static const _chip = 18.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final layout = layoutWeek(
      days,
      eventsByDay,
      ref.watch(localTimeProvider),
      onlyAllDay: true,
    );
    final lanes = layout.laneCount.clamp(0, _allDayRowMaxChips);
    final singlesRows = layout.singles.values.fold(
      0,
      (max, list) => list.length > max ? list.length : max,
    );
    final rows = (lanes + singlesRows).clamp(0, _allDayRowMaxChips);
    final hidden = [
      for (var i = 0; i < days.length; i++)
        layout.spans
            .where(
              (s) => s.lane >= lanes && s.startColumn <= i && s.endColumn >= i,
            )
            .length,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _gutterWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 6),
            child: Text(
              l10n.allDayShort,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columnWidth = constraints.maxWidth / days.length;
              return Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < days.length; i++)
                        Expanded(
                          child: _AllDayCell(
                            day: days[i],
                            singles: layout.singles[days[i]] ?? const [],
                            reservedRows: lanes,
                            totalRows: rows,
                            hiddenSpans: hidden[i],
                            highlight: scheme.primaryContainer.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final span in layout.spans)
                    if (span.lane < lanes)
                      Positioned(
                        left: columnWidth * span.startColumn,
                        width:
                            columnWidth *
                            (span.endColumn - span.startColumn + 1),
                        top: 2 + span.lane * _chip,
                        height: _chip,
                        child: MonthEventChip(
                          event: span.event,
                          continuesBefore: span.continuesBefore,
                          continuesAfter: span.continuesAfter,
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AllDayCell extends ConsumerWidget {
  const _AllDayCell({
    required this.day,
    required this.singles,
    required this.reservedRows,
    required this.totalRows,
    required this.hiddenSpans,
    required this.highlight,
  });

  final Day day;
  final List<CalendarEvent> singles;
  final int reservedRows;
  final int totalRows;
  final int hiddenSpans;
  final Color highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final room = (totalRows - reservedRows).clamp(0, _allDayRowMaxChips);
    final overflow = singles.length > room || hiddenSpans > 0;
    final shown = overflow ? (room - 1).clamp(0, room) : room;
    final more = hiddenSpans + (singles.length - shown).clamp(0, 999);
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
      builder: (context, candidates, rejected) => Container(
        constraints: BoxConstraints(
          minHeight: 20 + totalRows * _AllDayRow._chip,
        ),
        color: candidates.isNotEmpty ? highlight : null,
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: reservedRows * _AllDayRow._chip),
            for (final e in singles.take(shown)) MonthEventChip(event: e),
            if (overflow && more > 0)
              Text(
                l10n.moreEvents(more),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _DayColumn extends ConsumerWidget {
  const _DayColumn({
    required this.day,
    required this.events,
    required this.nowMinute,
  });

  final Day day;
  final List<CalendarEvent> events;
  final int? nowMinute;

  int _minuteAt(double dy) => snapMinutes((dy / _hourHeight * 60).round());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final toLocal = ref.watch(localTimeProvider);
    final positioned = layoutTimedEvents(events, day, toLocal);
    final overlapping = overlappingEventIds(events);

    return DragTarget<CalendarEvent>(
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject()! as RenderBox;
        final local = box.globalToLocal(details.offset);
        saveMovedEvent(
          context,
          ref,
          moveToWallTime(
            details.data,
            day,
            _minuteAt(local.dy),
            display: ref.read(displayLocationProvider),
          ),
        );
      },
      builder: (context, candidates, rejected) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => showQuickCreate(
          context,
          ref,
          day: day,
          startMinute: _minuteAt(details.localPosition.dy - _hourHeight / 4),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(
                      line: theme.dividerColor,
                      pixelRatio: MediaQuery.devicePixelRatioOf(context),
                      highlight: candidates.isNotEmpty
                          ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.3,
                            )
                          : null,
                    ),
                  ),
                ),
                for (final p in positioned)
                  Positioned(
                    top: p.startMinute / 60 * _hourHeight,
                    height: (p.endMinute - p.startMinute) / 60 * _hourHeight,
                    left: width * p.column / p.columns,
                    width: width / p.columns,
                    child: _TimedEventTile(
                      event: p.event,
                      day: day,
                      overlapping: overlapping.contains(p.event.id),
                      size: Size(
                        width / p.columns,
                        (p.endMinute - p.startMinute) / 60 * _hourHeight,
                      ),
                    ),
                  ),
                if (nowMinute != null)
                  Positioned(
                    top: nowMinute! / 60 * _hourHeight - 1,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 2,
                        color: theme.colorScheme.error,
                      ),
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

class _TimedEventTile extends ConsumerWidget {
  const _TimedEventTile({
    required this.event,
    required this.day,
    required this.overlapping,
    required this.size,
  });

  final CalendarEvent event;
  final Day day;
  final bool overlapping;
  final Size size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = eventColor(ref, context, event);
    final toLocal = ref.watch(localTimeProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final time = formatEventTimeOnDay(event, day, toLocal);

    Widget body() => Container(
      margin: const EdgeInsets.fromLTRB(1, 1, 2, 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.25),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      // Narrow or short tiles: the content is clipped instead of
      // overflowing.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (overlapping || eventIcon(event) != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        overlapping
                            ? Icons.warning_amber_rounded
                            : eventIcon(event),
                        size: 12,
                        semanticLabel: overlapping ? l10n.overlapWarning : null,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: size.height > 40 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              if (size.height > 34 && time != null)
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: theme.textTheme.labelSmall,
                ),
              if (size.height > 60 && event.location != null)
                Text(
                  event.location!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: () => openEvent(context, event),
      onSecondaryTapUp: (details) =>
          showEventMenu(context, ref, event, details.globalPosition),
      child: Semantics(
        button: true,
        label: [event.title, ?time].join(', '),
        child: EventDragSource(
          event: event,
          feedback: SizedBox.fromSize(size: size, child: body()),
          child: body(),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.line, required this.pixelRatio, this.highlight});

  final Color line;
  final double pixelRatio;
  final Color? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (highlight != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = highlight!);
    }
    // One physical pixel, snapped to the pixel grid: crisp and never
    // dropped at fractional positions.
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1 / pixelRatio;
    for (var h = 0; h <= 24; h++) {
      final y = snapToPixel(h * _hourHeight, pixelRatio);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final x = snapToPixel(0, pixelRatio);
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.line != line ||
      old.highlight != highlight ||
      old.pixelRatio != pixelRatio;
}
