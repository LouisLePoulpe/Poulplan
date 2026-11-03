import 'package:meta/meta.dart';

enum AppThemeMode { system, light, dark }

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.firstDayOfWeek = DateTime.monday,
    this.showHolidays = true,
    this.alsaceMoselle = false,
    this.schoolZone,
  });

  static const defaults = AppSettings();

  final AppThemeMode themeMode;

  /// ISO weekday the weeks start on (Monday = 1 … Sunday = 7).
  final int firstDayOfWeek;

  /// Display French public holidays.
  final bool showHolidays;

  /// Add the Alsace-Moselle holidays (Good Friday, 26 December).
  final bool alsaceMoselle;

  /// School holidays zone to display (`A`, `B`, `C`, `Corse`), or none.
  final String? schoolZone;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    int? firstDayOfWeek,
    bool? showHolidays,
    bool? alsaceMoselle,
    String? Function()? schoolZone,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
    showHolidays: showHolidays ?? this.showHolidays,
    alsaceMoselle: alsaceMoselle ?? this.alsaceMoselle,
    schoolZone: schoolZone != null ? schoolZone() : this.schoolZone,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.firstDayOfWeek == firstDayOfWeek &&
      other.showHolidays == showHolidays &&
      other.alsaceMoselle == alsaceMoselle &&
      other.schoolZone == schoolZone;

  @override
  int get hashCode => Object.hash(
    themeMode,
    firstDayOfWeek,
    showHolidays,
    alsaceMoselle,
    schoolZone,
  );
}
