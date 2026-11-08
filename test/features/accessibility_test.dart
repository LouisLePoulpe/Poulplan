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
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/holidays/school_holidays.dart';
import 'package:poulplan/features/calendar/providers/calendar_providers.dart';
import 'package:poulplan/features/maps/maps_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Basic accessibility: tap targets, labels and contrast (Flutter's
/// guidelines), and large text on a phone without overflow.
void main() {
  late AppDatabase db;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('fr');
  });

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(
      () => EventRepository(db).create(
        title: 'Dentiste',
        location: 'Cabinet',
        start: DateTime.utc(2026, 11, 3, 9),
        end: DateTime.utc(2026, 11, 3, 10),
        timeZone: 'UTC',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWithValue(Day(2026, 11, 3)),
          deviceTimeZoneProvider.overrideWithValue('UTC'),
          mapStyleProvider.overrideWith((ref) => Future.error('offline')),
          schoolHolidaysProvider.overrideWith(
            (ref) => SchoolHolidayCalendar.fromJson(
              File('assets/data/school_holidays_fr.json').readAsStringSync(),
            ),
          ),
        ],
        child: const PoulplanApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  Future<void> checkGuidelines(WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  }

  testWidgets('calendar screen meets the guidelines', (tester) async {
    await pumpApp(tester);
    await checkGuidelines(tester);
    await unmount(tester);
  });

  testWidgets('the editor meets the guidelines', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Nouvel événement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Plus d'options"));
    await tester.pumpAndSettle();
    await checkGuidelines(tester);
    await unmount(tester);
  });

  testWidgets('the settings meet the guidelines', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();
    await checkGuidelines(tester);
    await unmount(tester);
  });

  testWidgets('text at 200 % fits on a phone', (tester) async {
    await pumpApp(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Dentiste').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
