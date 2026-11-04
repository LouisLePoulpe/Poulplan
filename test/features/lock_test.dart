import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poulplan/app.dart';
import 'package:poulplan/core/time/device_time_zone.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/providers.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/holidays/school_holidays.dart';
import 'package:poulplan/domain/security/pin.dart';
import 'package:poulplan/features/calendar/providers/calendar_providers.dart';
import 'package:poulplan/features/lock/lock_controller.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('fr');
  });

  testWidgets('a locked app asks for the PIN', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWithValue(Day(2026, 11, 3)),
          deviceTimeZoneProvider.overrideWithValue('UTC'),
          schoolHolidaysProvider.overrideWith(
            (ref) => SchoolHolidayCalendar.fromJson(
              File('assets/data/school_holidays_fr.json').readAsStringSync(),
            ),
          ),
          initialLockStateProvider.overrideWithValue(
            AppLockState(
              pinHash: hashPin('2468', iterations: 100),
              locked: true,
            ),
          ),
        ],
        child: const PoulplanApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Poulplan est verrouillé'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1111');
    await tester.tap(find.text('Déverrouiller'));
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2468');
    await tester.tap(find.text('Déverrouiller'));
    await tester.pumpAndSettle();
    expect(find.text('Poulplan est verrouillé'), findsNothing);
    expect(find.text('Toussaint'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
