import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/time/device_time_zone.dart';
import '../../../data/providers.dart';
import '../../../domain/calendar/day.dart';
import '../../../domain/calendar/event_days.dart';
import '../../../domain/calendar/month_grid.dart';
import '../../../domain/entities/calendar_event.dart';
import '../../../domain/holidays/french_holidays.dart';
import '../../../domain/holidays/school_holidays.dart';

enum CalendarViewType { day, week, month, year, agenda }

/// Today, overridable in tests.
final todayProvider = Provider<Day>((ref) => Day.today());

/// Zone used to display events (the device's zone).
final displayLocationProvider = Provider<tz.Location>((ref) {
  final name = ref.watch(deviceTimeZoneProvider);
  try {
    return tz.getLocation(name);
  } catch (_) {
    return tz.UTC;
  }
});

/// UTC → wall-clock time of the display zone.
final localTimeProvider = Provider<LocalTime>((ref) {
  final location = ref.watch(displayLocationProvider);
  return (utc) => tz.TZDateTime.from(utc, location);
});

class CalendarViewNotifier extends Notifier<CalendarViewType> {
  @override
  CalendarViewType build() => CalendarViewType.month;

  void select(CalendarViewType view) => state = view;
}

final calendarViewProvider =
    NotifierProvider<CalendarViewNotifier, CalendarViewType>(
      CalendarViewNotifier.new,
    );

/// The day the calendar is centered on, shared by all views.
class FocusedDay extends Notifier<Day> {
  @override
  Day build() => ref.read(todayProvider);

  void set(Day day) => state = day;

  void goToToday() => state = ref.read(todayProvider);

  /// Moves by one page of [view] (one day, week, month or year).
  void step(CalendarViewType view, int direction) {
    state = switch (view) {
      CalendarViewType.day => state.addDays(direction),
      CalendarViewType.week => state.addDays(7 * direction),
      CalendarViewType.month ||
      CalendarViewType.agenda => state.addMonths(direction),
      CalendarViewType.year => state.addMonths(12 * direction),
    };
  }
}

final focusedDayProvider = NotifierProvider<FocusedDay, Day>(FocusedDay.new);

/// First day of the week containing the focused day.
final weekStartProvider = Provider<Day>((ref) {
  final day = ref.watch(focusedDayProvider);
  final firstDay = ref.watch(settingsProvider.select((s) => s.firstDayOfWeek));
  return day.startOfWeek(firstDay);
});

final monthGridProvider = Provider<List<Day>>((ref) {
  final month = ref.watch(focusedDayProvider.select((d) => d.firstDayOfMonth));
  final firstDay = ref.watch(settingsProvider.select((s) => s.firstDayOfWeek));
  return monthGridDays(month, firstDayOfWeek: firstDay);
});

/// Inclusive range of days.
typedef DayRange = ({Day first, Day last});

/// Public holidays used by series holiday rules (and displayed if enabled).
final holidayCalendarProvider = Provider<HolidayCalendar>((ref) {
  final alsace = ref.watch(settingsProvider.select((s) => s.alsaceMoselle));
  return HolidayCalendar(alsaceMoselle: alsace);
});

/// Bundled school holidays.
final schoolHolidaysProvider = FutureProvider<SchoolHolidayCalendar>((
  ref,
) async {
  try {
    return SchoolHolidayCalendar.fromJson(
      await rootBundle.loadString('assets/data/school_holidays_fr.json'),
    );
  } catch (_) {
    return SchoolHolidayCalendar.empty;
  }
});

/// Everything to display on [DayRange] (events with recurrences expanded,
/// holidays, school holidays, birthdays), grouped by local day.
final eventsByDayProvider =
    StreamProvider.family<Map<Day, List<CalendarEvent>>, DayRange>((
      ref,
      range,
    ) {
      final toLocal = ref.watch(localTimeProvider);
      final display = ref.watch(displayLocationProvider);
      final holidays = ref.watch(holidayCalendarProvider);
      final settings = ref.watch(settingsProvider);
      final school =
          ref.watch(schoolHolidaysProvider).value ??
          SchoolHolidayCalendar.empty;
      final birthdays = ref.watch(birthdaysProvider).value ?? const [];
      final extra = [
        if (settings.showHolidays)
          for (final MapEntry(key: day, value: name)
              in holidays.between(range.first, range.last).entries)
            holidayEvent(day, name),
        if (settings.schoolZone != null)
          for (final period in school.between(
            settings.schoolZone!,
            range.first,
            range.last,
          ))
            period.toEvent(),
        for (final b in birthdays) ...b.occurrences(range.first, range.last),
      ];
      return ref
          .watch(eventRepositoryProvider)
          .watchBetween(
            range.first,
            range.last,
            display: display,
            holidays: holidays,
          )
          .map(
            (events) => groupEventsByDay(
              [...extra, ...events],
              range.first,
              range.last,
              toLocal,
            ),
          );
    });

/// ARGB color of each category, by id.
final categoryColorsProvider = Provider<Map<String, int>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? const [];
  return {for (final c in categories) c.id: c.color};
});
