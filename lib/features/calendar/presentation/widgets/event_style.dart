import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/calendar_event.dart';
import '../../providers/calendar_providers.dart';

const _holidayColor = 0xFFE53935;
const _schoolHolidayColor = 0xFF78909C;
const _birthdayColor = 0xFFD81B60;

/// Event color: its own, else its category's, else the theme's primary.
/// Generated events (holidays, birthdays) have fixed colors.
Color eventColor(WidgetRef ref, BuildContext context, CalendarEvent event) {
  switch (event.kind) {
    case EventKind.holiday:
      return const Color(_holidayColor);
    case EventKind.schoolHoliday:
      return const Color(_schoolHolidayColor);
    case EventKind.birthday:
      return const Color(_birthdayColor);
    case EventKind.event:
      final categories = ref.watch(categoryColorsProvider);
      final fallback = Theme.of(context).colorScheme.primary;
      return Color(
        event.color ?? categories[event.categoryId] ?? fallback.toARGB32(),
      );
  }
}

/// Small icon shown before the title of generated or recurring events.
IconData? eventIcon(CalendarEvent event) => switch (event.kind) {
  EventKind.holiday => Icons.flag_outlined,
  EventKind.schoolHoliday => Icons.school_outlined,
  EventKind.birthday => Icons.cake_outlined,
  EventKind.event => event.isRecurring ? Icons.repeat : null,
};

Color foregroundOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;
