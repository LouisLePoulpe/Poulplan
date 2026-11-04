import '../../domain/entities/app_settings.dart';
import '../db/app_database.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _themeMode = 'theme_mode';
  static const _firstDayOfWeek = 'first_day_of_week';
  static const _showHolidays = 'show_holidays';
  static const _alsaceMoselle = 'alsace_moselle';
  static const _schoolZone = 'school_zone';
  static const _defaultReminder = 'default_reminder';
  static const _runInBackground = 'run_in_background';
  static const _autoBackup = 'backup_auto';
  static const _cloudBackup = 'backup_cloud';

  Stream<AppSettings> watch() => _db.select(_db.settings).watch().map((rows) {
    final values = {for (final r in rows) r.key: r.value};
    return AppSettings(
      themeMode:
          AppThemeMode.values.asNameMap()[values[_themeMode]] ??
          AppSettings.defaults.themeMode,
      firstDayOfWeek:
          _parseWeekday(values[_firstDayOfWeek]) ??
          AppSettings.defaults.firstDayOfWeek,
      showHolidays: values[_showHolidays] != 'false',
      alsaceMoselle: values[_alsaceMoselle] == 'true',
      schoolZone: values[_schoolZone]?.isEmpty ?? true
          ? null
          : values[_schoolZone],
      defaultReminder: switch (values[_defaultReminder]) {
        null => AppSettings.defaults.defaultReminder,
        'none' => null,
        final v => int.tryParse(v),
      },
      runInBackground: values[_runInBackground] != 'false',
      autoBackup: values[_autoBackup] != 'false',
      cloudBackup: values[_cloudBackup] != 'false',
    );
  });

  Future<void> setThemeMode(AppThemeMode mode) => _set(_themeMode, mode.name);

  Future<void> setFirstDayOfWeek(int weekday) {
    assert(weekday >= DateTime.monday && weekday <= DateTime.sunday);
    return _set(_firstDayOfWeek, '$weekday');
  }

  Future<void> setShowHolidays(bool value) => _set(_showHolidays, '$value');

  Future<void> setAlsaceMoselle(bool value) => _set(_alsaceMoselle, '$value');

  Future<void> setSchoolZone(String? zone) => _set(_schoolZone, zone ?? '');

  Future<void> setDefaultReminder(int? minutes) =>
      _set(_defaultReminder, minutes?.toString() ?? 'none');

  Future<void> setRunInBackground(bool value) =>
      _set(_runInBackground, '$value');

  Future<void> setAutoBackup(bool value) => _set(_autoBackup, '$value');

  Future<void> setCloudBackup(bool value) => _set(_cloudBackup, '$value');

  /// Raw value of a local bookkeeping key (e.g. the last backup time).
  Future<String?> getValue(String key) async => (await (_db.select(
    _db.settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setValue(String key, String value) => _set(key, value);

  Future<void> _set(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  static int? _parseWeekday(String? raw) {
    final value = int.tryParse(raw ?? '');
    return value != null && value >= 1 && value <= 7 ? value : null;
  }
}
