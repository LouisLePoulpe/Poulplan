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
import 'package:poulplan/data/repositories/attachment_repository.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/data/repositories/settings_repository.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/holidays/school_holidays.dart';
import 'package:poulplan/features/calendar/presentation/views/month_view.dart';
import 'package:poulplan/features/calendar/providers/calendar_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  late AppDatabase db;
  late EventRepository events;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('fr');
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    events = EventRepository(db);
  });

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester, {Directory? directory}) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (directory != null)
            appDirectoryProvider.overrideWithValue(directory),
          todayProvider.overrideWithValue(Day(2026, 11, 3)),
          deviceTimeZoneProvider.overrideWithValue('UTC'),
          // Asset loading does not complete under the fake test clock.
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

  Future<void> weeklySeries(WidgetTester tester) async {
    await tester.runAsync(
      () => events.create(
        title: 'Piscine',
        // Tuesdays 17:00 UTC from 3 November 2026.
        start: DateTime.utc(2026, 11, 3, 17),
        end: DateTime.utc(2026, 11, 3, 18),
        timeZone: 'UTC',
        rrule: 'FREQ=WEEKLY',
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('public holidays are shown in the month view', (tester) async {
    await pumpApp(tester);
    expect(find.text('Toussaint'), findsOneWidget);
    expect(find.text('Armistice 1918'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('school holidays of the chosen zone are shown', (tester) async {
    await tester.runAsync(() => SettingsRepository(db).setSchoolZone('B'));
    await pumpApp(tester);
    // Toussaint holidays 2026 end on Sunday 1 November: the grid starts on
    // Monday 26 October, so one bar covers the whole first week.
    expect(find.text('Vacances de la Toussaint'), findsOneWidget);
    final bar = tester.getSize(
      find.ancestor(
        of: find.text('Vacances de la Toussaint'),
        matching: find.byType(MonthEventChip),
      ),
    );
    final cell = (1200 - 80) / 7; // window minus the navigation rail
    expect(bar.width, greaterThan(cell * 6.5));
    await unmount(tester);
  });

  testWidgets('a weekly series appears on every week', (tester) async {
    await pumpApp(tester);
    await weeklySeries(tester);
    // Tuesdays 3, 10, 17, 24 November and 1 December are in the grid.
    expect(find.text('Piscine'), findsNWidgets(5));
    await unmount(tester);
  });

  testWidgets('create a series from the editor', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Nouvel événement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Yoga');
    await tester.tap(find.text("Plus d'options"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ne se répète pas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toutes les semaines le mardi'));
    await tester.pumpAndSettle();
    expect(find.text('Toutes les semaines le mardi'), findsOneWidget);
    expect(find.text('Jours fériés'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Yoga'), findsNWidgets(5));
    await unmount(tester);
  });

  testWidgets('a series gets an end date from the editor', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Nouvel événement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Yoga');
    await tester.tap(find.text("Plus d'options"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ne se répète pas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toutes les semaines le mardi'));
    await tester.pumpAndSettle();
    expect(find.text('Début de la répétition'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('recurrence-end')));
    await tester.tap(find.byKey(const ValueKey('recurrence-end')));
    await tester.pumpAndSettle();
    // The picker opens on 3 December 2026.
    await tester.tap(find.text('17'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final rows = await tester.runAsync(() => db.select(db.events).get());
    expect(rows!.single.rrule, 'FREQ=WEEKLY;UNTIL=20261217');
    await unmount(tester);
  });

  testWidgets('reminders: default one plus one added in the editor', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Nouvel événement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Train');
    await tester.tap(find.text("Plus d'options"));
    await tester.pumpAndSettle();
    expect(find.text('10 min avant'), findsOneWidget);
    await tester.ensureVisible(find.text('Ajouter un rappel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter un rappel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 h avant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(
      () => events.watchBetween(Day(2026, 11, 1), Day(2026, 11, 30)).first,
    );
    expect(saved!.single.reminders, [10, 60]);
    await unmount(tester);
  });

  testWidgets('attachments are listed in the editor', (tester) async {
    final dir = Directory.systemTemp.createTempSync('poulplan_editor');
    addTearDown(() => dir.deleteSync(recursive: true));
    final event = await tester.runAsync(
      () => events.create(
        title: 'Train',
        start: DateTime.utc(2026, 11, 3, 8),
        end: DateTime.utc(2026, 11, 3, 9),
        timeZone: 'UTC',
      ),
    );
    await tester.runAsync(
      () => AttachmentRepository(
        db,
        directory: Directory('${dir.path}/attachments'),
      ).add(event!.id, 'billet.pdf', List.filled(2048, 0)),
    );
    await pumpApp(tester, directory: dir);
    await tester.tap(find.text('Train'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Pièces jointes'), findsOneWidget);
    expect(find.text('billet.pdf'), findsOneWidget);
    expect(find.text('2 ko · Sur cet appareil'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('edit only one occurrence', (tester) async {
    await pumpApp(tester);
    await weeklySeries(tester);
    await tester.tap(find.text('Piscine').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Piscine'),
      'Piscine annulée ?',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cet événement'));
    await tester.pumpAndSettle();
    expect(find.text('Piscine'), findsNWidgets(4));
    expect(find.text('Piscine annulée ?'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('delete this and following occurrences', (tester) async {
    await pumpApp(tester);
    await weeklySeries(tester);
    await tester.tap(find.text('Piscine').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cet événement et les suivants'));
    await tester.pumpAndSettle();
    expect(find.text('Piscine'), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('birthdays: add one and see it in the calendar', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Anniversaires'), 100);
    await tester.tap(find.text('Anniversaires'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvel anniversaire'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Léa');
    await tester.enterText(find.byType(TextField).last, '1996');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Léa'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    // The dialog defaults to the real current date: today in the test is
    // forced to 3 November 2026 only for the calendar, so check the agenda
    // through the database instead.
    final birthdays = await tester.runAsync(
      () => db.select(db.birthdays).get(),
    );
    expect(birthdays!.single.birthYear, 1996);
    await unmount(tester);
  });

  testWidgets('search finds events without accents and saves a filter', (
    tester,
  ) async {
    await tester.runAsync(
      () => events.create(
        title: 'Fête de Noël',
        location: 'École',
        start: DateTime.utc(2026, 12, 18, 17),
        end: DateTime.utc(2026, 12, 18, 19),
        timeZone: 'UTC',
      ),
    );
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'noel ecole');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Fête de Noël'), findsOneWidget);

    await tester.tap(find.byTooltip('Enregistrer le filtre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Noël');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Noël'), findsOneWidget);

    await tester.tap(find.text('Fête de Noël'));
    await tester.pumpAndSettle();
    expect(find.text("Modifier l'événement"), findsOneWidget);
    await unmount(tester);
  });
}
