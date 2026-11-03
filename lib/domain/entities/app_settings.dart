import 'package:meta/meta.dart';

enum AppThemeMode { system, light, dark }

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.firstDayOfWeek = DateTime.monday,
  });

  static const defaults = AppSettings();

  final AppThemeMode themeMode;

  /// ISO weekday the weeks start on (Monday = 1 … Sunday = 7).
  final int firstDayOfWeek;

  AppSettings copyWith({AppThemeMode? themeMode, int? firstDayOfWeek}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.firstDayOfWeek == firstDayOfWeek;

  @override
  int get hashCode => Object.hash(themeMode, firstDayOfWeek);
}
