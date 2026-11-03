import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/formatters.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/time/device_time_zone.dart';
import '../../../data/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../event_editor/presentation/quick_create.dart';
import '../providers/calendar_providers.dart';
import '../../sync/presentation/account_page.dart' show syncIcon;
import '../../sync/providers/sync_controller.dart';
import 'demo_events.dart';
import 'views/agenda_view.dart';
import 'views/month_view.dart';
import 'views/time_grid_view.dart';
import 'views/year_view.dart';

/// Main screen: the five calendar views.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  static const _wideBreakpoint = 840.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(calendarViewProvider);
    final focused = ref.read(focusedDayProvider.notifier);
    final views = ref.read(calendarViewProvider.notifier);
    void step(int direction) => focused.step(view, direction);
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    final destinations = [
      (CalendarViewType.day, Icons.view_day_outlined, l10n.viewDay),
      (CalendarViewType.week, Icons.view_week_outlined, l10n.viewWeek),
      (CalendarViewType.month, Icons.calendar_view_month, l10n.viewMonth),
      (CalendarViewType.year, Icons.calendar_today_outlined, l10n.viewYear),
      (CalendarViewType.agenda, Icons.view_agenda_outlined, l10n.viewAgenda),
    ];

    final body = switch (view) {
      CalendarViewType.day => const TimeGridView(
        key: ValueKey('day'),
        dayCount: 1,
      ),
      CalendarViewType.week => const TimeGridView(
        key: ValueKey('week'),
        dayCount: 7,
      ),
      CalendarViewType.month => const MonthView(),
      CalendarViewType.year => const YearView(),
      CalendarViewType.agenda => const AgendaView(),
    };

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => step(-1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => step(1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => step(1),
        const SingleActivator(LogicalKeyboardKey.keyT): focused.goToToday,
        const SingleActivator(LogicalKeyboardKey.keyN): () =>
            showQuickCreate(context, ref, day: ref.read(focusedDayProvider)),
        for (final (i, d) in destinations.indexed)
          SingleActivator(LogicalKeyboardKey(0x31 + i)): () =>
              views.select(d.$1),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            context.push(Routes.settings),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            context.push(Routes.search),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 4,
            title: Row(
              children: [
                IconButton(
                  tooltip: l10n.previous,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => step(-1),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_title(context, ref, view)),
                  ),
                ),
                IconButton(
                  tooltip: l10n.next,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => step(1),
                ),
              ],
            ),
            actions: [
              const _SyncIndicator(),
              IconButton(
                tooltip: l10n.search,
                icon: const Icon(Icons.search),
                onPressed: () => context.push(Routes.search),
              ),
              IconButton(
                tooltip: l10n.today,
                icon: const Icon(Icons.today),
                onPressed: focused.goToToday,
              ),
              IconButton(
                tooltip: l10n.settings,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(Routes.settings),
              ),
              if (kDebugMode) const _DebugMenu(),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: l10n.newEvent,
            onPressed: () => showQuickCreate(
              context,
              ref,
              day: ref.read(focusedDayProvider),
            ),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  height: 64,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  selectedIndex: view.index,
                  onDestinationSelected: (i) =>
                      views.select(CalendarViewType.values[i]),
                  destinations: [
                    for (final d in destinations)
                      NavigationDestination(icon: Icon(d.$2), label: d.$3),
                  ],
                ),
          body: SafeArea(
            top: false,
            child: Row(
              children: [
                if (wide) ...[
                  NavigationRail(
                    labelType: NavigationRailLabelType.all,
                    selectedIndex: view.index,
                    onDestinationSelected: (i) =>
                        views.select(CalendarViewType.values[i]),
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.$2),
                          label: Text(d.$3),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: _Swipeable(
                    enabled:
                        view != CalendarViewType.agenda &&
                        view != CalendarViewType.year,
                    onSwipe: step,
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title(BuildContext context, WidgetRef ref, CalendarViewType view) {
    final locale = localeOf(context);
    final day = ref.watch(focusedDayProvider);
    switch (view) {
      case CalendarViewType.day:
        return formatDayLong(context, day);
      case CalendarViewType.week:
        final start = ref.watch(weekStartProvider);
        final end = start.addDays(6);
        final sameMonth = start.month == end.month;
        final from = sameMonth
            ? '${start.day}'
            : DateFormat.MMMd(locale).format(start.toLocalMidnight());
        return '$from – ${DateFormat.yMMMd(locale).format(end.toLocalMidnight())}';
      case CalendarViewType.month:
        return toBeginningOfSentenceCase(
          DateFormat.yMMMM(locale).format(day.toLocalMidnight()),
          locale,
        );
      case CalendarViewType.year:
        return '${day.year}';
      case CalendarViewType.agenda:
        return AppLocalizations.of(context)
            .agendaFrom(formatDayShort(context, day));
    }
  }
}

/// Horizontal swipe to change page on touch screens.
class _Swipeable extends StatelessWidget {
  const _Swipeable({
    required this.enabled,
    required this.onSwipe,
    required this.child,
  });

  final bool enabled;
  final void Function(int direction) onSwipe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) onSwipe(-1);
        if (velocity < -300) onSwipe(1);
      },
      child: child,
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

/// Cloud status, shown only when signed in.
class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    if (!status.signedIn) return const SizedBox();
    final conflicts = ref.watch(syncConflictsProvider).value?.length ?? 0;
    return IconButton(
      tooltip: AppLocalizations.of(context).account,
      icon: Badge(
        isLabelVisible: conflicts > 0,
        label: Text('$conflicts'),
        child: Icon(syncIcon(status.phase)),
      ),
      onPressed: () => context.push(Routes.account),
    );
  }
}
