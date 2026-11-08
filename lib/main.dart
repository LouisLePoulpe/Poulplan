import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/debug/screenshot_extension.dart';
import 'core/platform/desktop_integration.dart';
import 'core/time/device_time_zone.dart';
import 'data/db/app_database.dart';
import 'data/db/connection.dart';
import 'data/sync/change_recorder.dart';
import 'features/reminders/reminder_scheduler.dart';
import 'features/backup/backup_manager.dart';
import 'features/lock/lock_controller.dart';
import 'data/repositories/settings_repository.dart';
import 'features/widgets/widget_exporter.dart';
import 'data/providers.dart';
import 'core/platform/app_directory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  final timeZone = await initTimeZones();
  final database = AppDatabase(openAppDatabaseConnection());
  final clock = await loadHlcClock(database);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      hlcClockProvider.overrideWithValue(clock),
      deviceTimeZoneProvider.overrideWithValue(timeZone),
      initialLockStateProvider.overrideWithValue(
        await loadLockState(SettingsRepository(database)),
      ),
      appDirectoryProvider.overrideWithValue(await appDataDirectory()),
    ],
  );
  registerDebugExtensions(container);
  final settings = await container
      .read(settingsRepositoryProvider)
      .watch()
      .first;
  await DesktopIntegration.setHideOnClose(settings.runInBackground);
  unawaited(container.read(reminderSchedulerProvider).start());
  container.read(widgetExporterProvider).start();
  container.read(backupManagerProvider).start();
  unawaited(container.read(linuxTrayProvider).start());
  runApp(
    UncontrolledProviderScope(container: container, child: const PoulplanApp()),
  );
}
