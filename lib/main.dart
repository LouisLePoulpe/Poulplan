import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/debug/screenshot_extension.dart';
import 'core/time/device_time_zone.dart';
import 'data/db/app_database.dart';
import 'data/db/connection.dart';
import 'data/sync/change_recorder.dart';
import 'data/providers.dart';

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
    ],
  );
  registerDebugExtensions(container);
  runApp(
    UncontrolledProviderScope(container: container, child: const PoulplanApp()),
  );
}
