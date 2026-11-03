import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:poulplan/features/reminders/reminder_scheduler.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  final created = DateTime.utc(2026, 1, 1);
  CalendarEvent event(
    DateTime start, {
    String? location,
    bool allDay = false,
  }) => CalendarEvent(
    id: 'e',
    title: 'e',
    allDay: allDay,
    location: location,
    start: start,
    end: start.add(const Duration(hours: 1)),
    timeZone: 'UTC',
    createdAt: created,
    updatedAt: created,
  );
  DateTime utc(DateTime d) => d;

  test('today, tomorrow and later', () {
    final now = DateTime.utc(2026, 11, 3, 8);
    expect(
      reminderBody(event(DateTime.utc(2026, 11, 3, 14, 30)), now, utc),
      "Aujourd'hui à 14:30",
    );
    expect(
      reminderBody(
        event(DateTime.utc(2026, 11, 4, 9), location: 'Lyon'),
        now,
        utc,
      ),
      'Demain à 09:00 · Lyon',
    );
    expect(
      reminderBody(event(DateTime.utc(2026, 11, 10), allDay: true), now, utc),
      'Mar. 10 nov.',
    );
  });
}
