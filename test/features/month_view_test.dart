import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poulplan/app.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/providers.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/calendar/event_days.dart';
import 'package:poulplan/features/calendar/providers/calendar_providers.dart';

void main() {
  late AppDatabase db;

  setUpAll(() => initializeDateFormatting('fr'));

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWithValue(Day(2026, 11, 3)),
          localTimeProvider.overrideWithValue((utc) => utc),
        ],
        child: const PoulplanApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Drift stream queries schedule a zero-duration timer on close: let the
  // widget tree go away before the test ends.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('shows the current month in French', (tester) async {
    await pumpApp(tester);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.text('lun.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an event inserted in the database appears in the month view', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Anniversaire de Léa'), findsNothing);

    await tester.runAsync(
      () => EventRepository(db).create(
        title: 'Anniversaire de Léa',
        start: DateTime.utc(2026, 11, 14, 18),
        end: DateTime.utc(2026, 11, 14, 22),
        timeZone: 'UTC',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Anniversaire de Léa'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('navigates to next and previous months', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Mois suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Décembre 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Mois précédent'));
    await tester.tap(find.byTooltip('Mois précédent'));
    await tester.pumpAndSettle();
    expect(find.text('Octobre 2026'), findsOneWidget);
    await tester.tap(find.byTooltip("Aujourd'hui"));
    await tester.pumpAndSettle();
    expect(find.text('Novembre 2026'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('settings change the theme and the first day of week', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    await tester.tap(find.text('Lundi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dimanche').last);
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

  test('deviceLocalTime converts to local', () {
    final utc = DateTime.utc(2026, 1, 1);
    expect(deviceLocalTime(utc), utc.toLocal());
  });
}
