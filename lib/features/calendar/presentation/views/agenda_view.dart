import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formatters.dart';
import '../../../../domain/calendar/day.dart';
import '../../../../domain/calendar/day_layout.dart';
import '../../../../domain/entities/calendar_event.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../providers/calendar_providers.dart';
import '../event_actions.dart';
import '../widgets/event_style.dart';

/// How many days the agenda shows from the focused day.
class AgendaLength extends Notifier<int> {
  static const page = 60;

  @override
  int build() {
    ref.watch(focusedDayProvider);
    return page;
  }

  void more() => state += page;
}

final agendaLengthProvider = NotifierProvider<AgendaLength, int>(
  AgendaLength.new,
);

class AgendaView extends ConsumerWidget {
  const AgendaView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final first = ref.watch(focusedDayProvider);
    final length = ref.watch(agendaLengthProvider);
    final last = first.addDays(length - 1);
    final async = ref.watch(eventsByDayProvider((first: first, last: last)));
    final byDay = async.value ?? const {};
    final today = ref.watch(todayProvider);

    final children = <Widget>[];
    for (final MapEntry(key: day, value: events) in byDay.entries) {
      final overlapping = overlappingEventIds(events);
      children.add(_DayHeader(day: day, isToday: day == today));
      for (final event in events) {
        children.add(
          _AgendaTile(
            event: event,
            day: day,
            overlapping: overlapping.contains(event.id),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (async.hasValue && byDay.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n.agendaEmpty(formatDayShort(context, last)),
              textAlign: TextAlign.center,
            ),
          ),
        ...children,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.expand_more),
              label: Text(l10n.agendaShowMore),
              onPressed: ref.read(agendaLengthProvider.notifier).more,
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends ConsumerWidget {
  const _DayHeader({required this.day, required this.isToday});

  final Day day;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        ref.read(focusedDayProvider.notifier).set(day);
        ref.read(calendarViewProvider.notifier).select(CalendarViewType.day);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          formatDayLong(context, day),
          style: theme.textTheme.titleSmall?.copyWith(
            color: isToday ? theme.colorScheme.primary : null,
            fontWeight: isToday ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}

class _AgendaTile extends ConsumerWidget {
  const _AgendaTile({
    required this.event,
    required this.day,
    required this.overlapping,
  });

  final CalendarEvent event;
  final Day day;
  final bool overlapping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final color = eventColor(ref, context, event);
    final toLocal = ref.watch(localTimeProvider);
    final time = formatEventTimeOnDay(event, day, toLocal) ?? l10n.allDay;
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          showEventMenu(context, ref, event, details.globalPosition),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 6,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        title: Row(
          children: [
            if (eventIcon(event) != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(eventIcon(event), size: 16),
              ),
            Flexible(child: Text(event.title)),
          ],
        ),
        subtitle: Text([time, ?event.location].join(' · ')),
        trailing: overlapping
            ? Tooltip(
                message: l10n.overlapWarning,
                child: const Icon(Icons.warning_amber_rounded),
              )
            : null,
        onTap: () => openEvent(context, event),
        onLongPress: () {
          final box = context.findRenderObject()! as RenderBox;
          showEventMenu(
            context,
            ref,
            event,
            box.localToGlobal(box.size.center(Offset.zero)),
          );
        },
      ),
    );
  }
}
