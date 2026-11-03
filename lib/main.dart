import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/debug/screenshot_extension.dart';
import 'core/time/device_time_zone.dart';
import 'data/db/app_database.dart';
import 'data/db/connection.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerScreenshotExtension();
  await initializeDateFormatting('fr');
  final timeZone = await initTimeZones();
  final database = AppDatabase(openAppDatabaseConnection());
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        deviceTimeZoneProvider.overrideWithValue(timeZone),
      ],
      child: const PoulplanApp(),
    ),
  );
}
