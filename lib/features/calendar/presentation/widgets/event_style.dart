import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/calendar_event.dart';
import '../../providers/calendar_providers.dart';

/// Event color: its own, else its category's, else the theme's primary.
Color eventColor(WidgetRef ref, BuildContext context, CalendarEvent event) {
  final categories = ref.watch(categoryColorsProvider);
  final fallback = Theme.of(context).colorScheme.primary;
  return Color(
    event.color ?? categories[event.categoryId] ?? fallback.toARGB32(),
  );
}

Color foregroundOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;
