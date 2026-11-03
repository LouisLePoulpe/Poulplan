import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/calendar/day.dart';
import '../../../domain/calendar/event_days.dart';
import '../../../domain/calendar/month_grid.dart';
import '../../../domain/entities/calendar_event.dart';

/// Today, overridable in tests.
final todayProvider = Provider<Day>((ref) => Day.today());

/// Display time zone converter, overridable in tests.
final localTimeProvider = Provider<LocalTime>((ref) => deviceLocalTime);

/// First day of the month shown by the month view.
class VisibleMonth extends Notifier<Day> {
  @override
  Day build() => ref.read(todayProvider).firstDayOfMonth;

  void next() => state = state.addMonths(1);

  void previous() => state = state.addMonths(-1);

  void goToToday() => state = ref.read(todayProvider).firstDayOfMonth;
}

final visibleMonthProvider = NotifierProvider<VisibleMonth, Day>(
  VisibleMonth.new,
);

final monthGridProvider = Provider<List<Day>>((ref) {
  final month = ref.watch(visibleMonthProvider);
  final firstDay = ref.watch(settingsProvider.select((s) => s.firstDayOfWeek));
  return monthGridDays(month, firstDayOfWeek: firstDay);
});

/// Events of the visible grid, grouped by local day.
final monthEventsProvider = StreamProvider<Map<Day, List<CalendarEvent>>>((
  ref,
) {
  final days = ref.watch(monthGridProvider);
  final toLocal = ref.watch(localTimeProvider);
  return ref
      .watch(eventRepositoryProvider)
      .watchBetween(days.first, days.last)
      .map(
        (events) => groupEventsByDay(events, days.first, days.last, toLocal),
      );
});

/// ARGB color of each category, by id.
final categoryColorsProvider = Provider<Map<String, int>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? const [];
  return {for (final c in categories) c.id: c.color};
});
