import 'package:flutter/material.dart';

import '../../domain/entities/app_settings.dart';

/// Colors from the Poulplan logo.
abstract final class BrandColors {
  static const yellow = Color(0xFFFFE600);
  static const brown = Color(0xFF8F6400);
  static const cream = Color(0xFFFFF6C2);
  static const darkBrown = Color(0xFF2C1E00);
  static const night = Color(0xFF1E1A0E);
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.yellow,
          brightness: Brightness.light,
        ).copyWith(
          primary: BrandColors.brown,
          onPrimary: Colors.white,
          primaryContainer: BrandColors.yellow,
          onPrimaryContainer: BrandColors.darkBrown,
        );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.yellow,
          brightness: Brightness.dark,
        ).copyWith(
          primary: BrandColors.yellow,
          onPrimary: BrandColors.darkBrown,
          primaryContainer: BrandColors.brown,
          onPrimaryContainer: BrandColors.cream,
        );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) => ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
    ),
  );
}

ThemeMode toFlutterThemeMode(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};
