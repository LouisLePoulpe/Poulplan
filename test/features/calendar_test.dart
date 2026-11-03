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
import 'package:poulplan/domain/entities/calendar_event.dart';
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

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWithValue(Day(2026, 11, 3)),
          deviceTimeZoneProvider.overrideWithValue('UTC'),
        ],
        child: const PoulplanApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Drift stream queries and the time grid clock use timers: tear the tree
  // down before the test ends.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  Future<CalendarEvent> insert(
    WidgetTester tester,
    String title,
    DateTime start,
    DateTime end, {
    bool allDay = false,
  }) async {
    final event = await tester.runAsync(
      () => events.create(
        title: title,
        allDay: allDay,
        start: start,
        end: end,
        timeZone: 'UTC',
      ),
    );
    await tester.pumpAndSettle();
    return event!;
  }

  Future<List<CalendarEvent>> allEvents(WidgetTester tester) async =>
      (await tester.runAsync(
        () => events.watchBetween(Day(2026, 1, 1), Day(2027, 12, 31)).first,
      ))!;

  Future<void> selectView(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('month view in French, navigation and today', (tester) async {
    await pumpApp(tester);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.text('lun.'), findsOneWidget);
    await tester.tap(find.byTooltip('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Décembre 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Précédent'));
    await tester.tap(find.byTooltip('Précédent'));
    await tester.pumpAndSettle();
    expect(find.text('Octobre 2026'), findsOneWidget);
    await tester.tap(find.byTooltip("Aujourd'hui"));
    await tester.pumpAndSettle();
    expect(find.text('Novembre 2026'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an event inserted in the database appears in all five views', (
    tester,
  ) async {
    await pumpApp(tester);
    await insert(
      tester,
      'Réunion',
      DateTime.utc(2026, 11, 3, 9),
      DateTime.utc(2026, 11, 3, 10),
    );
    expect(find.text('Réunion'), findsOneWidget);

    await selectView(tester, 'Jour');
    expect(find.text('Mardi 3 novembre 2026'), findsOneWidget);
    expect(find.text('Réunion'), findsOneWidget);
    expect(find.text('09:00 – 10:00'), findsOneWidget);

    await selectView(tester, 'Semaine');
    expect(find.text('2 – 8 nov. 2026'), findsOneWidget);
    expect(find.text('Réunion'), findsOneWidget);

    await selectView(tester, 'Agenda');
    expect(find.text('Réunion'), findsOneWidget);
    expect(find.text('Mardi 3 novembre 2026'), findsOneWidget);

    await selectView(tester, 'Année');
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Novembre'), findsOneWidget);
    // Tapping a day of the year view opens the day view.
    await tester.tap(find.text('Décembre'));
    await tester.pumpAndSettle();
    expect(find.text('Décembre 2026'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('quick creation from the + button', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Nouvel événement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Piscine');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Piscine'), findsOneWidget);
    final saved = await allEvents(tester);
    expect(saved.single.title, 'Piscine');
    expect(Day.fromDateTime(saved.single.start), Day(2026, 11, 3));
    await unmount(tester);
  });

  testWidgets('quick creation refuses an empty title', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Nouvel événement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Le titre est obligatoire'), findsOneWidget);
    expect(await allEvents(tester), isEmpty);
    await unmount(tester);
  });

  testWidgets('edit, delete, undo and duplicate through the editor', (
    tester,
  ) async {
    await pumpApp(tester);
    await insert(
      tester,
      'Dentiste',
      DateTime.utc(2026, 11, 5, 14),
      DateTime.utc(2026, 11, 5, 15),
    );

    // Edit.
    await tester.tap(find.text('Dentiste'));
    await tester.pumpAndSettle();
    expect(find.text("Modifier l'événement"), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Dentiste'),
      'Orthodontiste',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Lieu'), 'Lyon');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Orthodontiste'), findsOneWidget);
    expect((await allEvents(tester)).single.location, 'Lyon');

    // Duplicate.
    await tester.tap(find.text('Orthodontiste'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dupliquer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Orthodontiste'), findsNWidgets(2));

    // Delete then undo.
    await tester.tap(find.text('Orthodontiste').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Orthodontiste'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Orthodontiste'), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('full editor creates a multi-day all-day event', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Nouvel événement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Vacances');
    await tester.tap(find.text("Plus d'options"));
    await tester.pumpAndSettle();
    expect(find.text('Nouvel événement'), findsOneWidget);
    await tester.tap(find.text('Toute la journée'));
    await tester.pumpAndSettle();
    // End date: pick the 6th.
    // The end date button (its date depends on the default start hour).
    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('end')),
            matching: find.byType(OutlinedButton),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('6'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final saved = (await allEvents(tester)).single;
    expect(saved.allDay, isTrue);
    expect(saved.start, DateTime.utc(2026, 11, 3));
    expect(saved.end, DateTime.utc(2026, 11, 7));
    // Shown on each of the 4 days.
    expect(find.text('Vacances'), findsNWidgets(4));
    await unmount(tester);
  });

  testWidgets('editor rejects an end before the start', (tester) async {
    await pumpApp(tester);
    await insert(
      tester,
      'Cours',
      DateTime.utc(2026, 11, 5, 14),
      DateTime.utc(2026, 11, 5, 15),
    );
    await tester.tap(find.text('Cours'));
    await tester.pumpAndSettle();
    // Move the end date one day earlier than the start.
    await tester.tap(find.text('jeu. 5 nov. 2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('4'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('La fin doit être après le début'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('drag and drop to another day in the month view', (tester) async {
    await pumpApp(tester);
    await insert(
      tester,
      'Réunion',
      DateTime.utc(2026, 11, 3, 9),
      DateTime.utc(2026, 11, 3, 10),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Réunion')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('20')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = (await allEvents(tester)).single;
    expect(moved.start, DateTime.utc(2026, 11, 20, 9));
    expect(moved.end, DateTime.utc(2026, 11, 20, 10));
    await unmount(tester);
  });

  testWidgets('drag and drop to another time in the day view', (tester) async {
    await pumpApp(tester);
    await insert(
      tester,
      'Réunion',
      DateTime.utc(2026, 11, 3, 9),
      DateTime.utc(2026, 11, 3, 10),
    );
    await selectView(tester, 'Jour');
    final start = tester.getCenter(find.text('Réunion'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600));
    // 5 hours lower on a 52 px/h grid.
    await gesture.moveTo(start + const Offset(0, 5 * 52));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = (await allEvents(tester)).single;
    expect(moved.start, DateTime.utc(2026, 11, 3, 14));
    expect(moved.end, DateTime.utc(2026, 11, 3, 15));
    await unmount(tester);
  });

  testWidgets('overlapping events are flagged', (tester) async {
    await pumpApp(tester);
    await insert(
      tester,
      'A',
      DateTime.utc(2026, 11, 3, 9),
      DateTime.utc(2026, 11, 3, 10),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    await insert(
      tester,
      'B',
      DateTime.utc(2026, 11, 3, 9, 30),
      DateTime.utc(2026, 11, 3, 11),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
    await selectView(tester, 'Jour');
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('narrow screens use a bottom navigation bar', (tester) async {
    await pumpApp(tester, size: const Size(412, 900));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Afficher plus'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('quick creation on a phone with the keyboard open', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1080, 2424));
    tester.view.devicePixelRatio = 2.6;
    // On-screen keyboard: about half of the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 1100);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nouvel événement'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text("Plus d'options"));
    await tester.tap(find.text("Plus d'options"));
    await tester.pumpAndSettle();
    expect(find.text('Nouvel événement'), findsOneWidget); // full editor
    await unmount(tester);
  });

  testWidgets('week view on a phone does not overflow', (tester) async {
    await pumpApp(tester, size: const Size(412, 900));
    await insert(
      tester,
      "Réunion d'équipe hebdomadaire",
      DateTime.utc(2026, 11, 3, 9),
      DateTime.utc(2026, 11, 3, 10),
    );
    await insert(
      tester,
      'Appel',
      DateTime.utc(2026, 11, 3, 11),
      DateTime.utc(2026, 11, 3, 11, 15),
    );
    await tester.tap(find.byIcon(Icons.view_week_outlined));
    await tester.pumpAndSettle();
    // A RenderFlex overflow would have thrown during layout.
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('settings: theme, first day of week and categories', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.text('Lundi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dimanche').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Catégories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle catégorie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sport');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Sport'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final headers = tester
        .widgetList<Text>(find.textContaining(RegExp(r'^\w+\.$')))
        .map((t) => t.data)
        .toList();
    expect(headers.first, 'dim.');
    await unmount(tester);
  });
}
