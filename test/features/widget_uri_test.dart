import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/widgets/widget_snapshot.dart';
import 'package:poulplan/features/widgets/widget_exporter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  WidgetEntry entry(Day day, String? time) => WidgetEntry(
    id: 'e',
    title: 'Dentiste',
    start: day.toUtcMidnight(),
    end: day.toUtcMidnight(),
    allDay: time == null,
    localDay: day,
    time: time,
    color: 0,
    location: null,
    openable: true,
  );

  WidgetSnapshot snapshot(List<WidgetEntry> upcoming) => WidgetSnapshot(
    generatedAt: DateTime.utc(2026),
    firstDayOfWeek: 1,
    upcoming: upcoming,
    busyDays: const {},
  );

  test('tray tooltip describes the next event', () {
    final today = Day(2026, 11, 3);
    expect(
      nextEventDescription(snapshot([entry(today, '14:30')]), today),
      "Prochain : Dentiste — Aujourd'hui à 14:30",
    );
    expect(
      nextEventDescription(snapshot([entry(Day(2026, 11, 4), null)]), today),
      'Prochain : Dentiste — Demain · Journée',
    );
    expect(
      nextEventDescription(
        snapshot([entry(Day(2026, 11, 10), '09:00')]),
        today,
      ),
      'Prochain : Dentiste — mar. 10 nov. à 09:00',
    );
    expect(
      nextEventDescription(snapshot([]), today),
      'Aucun événement à venir',
    );
  });

  test('event uri round-trip, including occurrence ids', () {
    for (final id in ['abc-123', 'series@1790000000000']) {
      expect(eventIdFromUri(eventUri(id)), id);
    }
  });

  test('new event uri', () {
    expect(isNewEventUri(Uri.parse('poulplan://new')), isTrue);
    expect(isNewEventUri(Uri.parse('poulplan://open')), isFalse);
    expect(eventIdFromUri(Uri.parse('poulplan://new')), isNull);
  });

  test('other uris open nothing in particular', () {
    expect(eventIdFromUri(Uri.parse('poulplan://open')), isNull);
    expect(eventIdFromUri(Uri.parse('https://example.org/event/x')), isNull);
    expect(eventIdFromUri(null), isNull);
  });
}
