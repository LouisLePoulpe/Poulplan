import '../../domain/entities/app_settings.dart';
import '../db/app_database.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _themeMode = 'theme_mode';
  static const _firstDayOfWeek = 'first_day_of_week';

  Stream<AppSettings> watch() => _db.select(_db.settings).watch().map((rows) {
    final values = {for (final r in rows) r.key: r.value};
    return AppSettings(
      themeMode:
          AppThemeMode.values.asNameMap()[values[_themeMode]] ??
          AppSettings.defaults.themeMode,
      firstDayOfWeek:
          _parseWeekday(values[_firstDayOfWeek]) ??
          AppSettings.defaults.firstDayOfWeek,
    );
  });

  Future<void> setThemeMode(AppThemeMode mode) => _set(_themeMode, mode.name);

  Future<void> setFirstDayOfWeek(int weekday) {
    assert(weekday >= DateTime.monday && weekday <= DateTime.sunday);
    return _set(_firstDayOfWeek, '$weekday');
  }

  Future<void> _set(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  static int? _parseWeekday(String? raw) {
    final value = int.tryParse(raw ?? '');
    return value != null && value >= 1 && value <= 7 ? value : null;
  }
}
