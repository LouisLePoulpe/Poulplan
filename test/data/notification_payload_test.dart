import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/data/notifications/notification_service.dart';

void main() {
  test('the end of the event travels with the notification', () {
    final payload = ReminderPayload(
      eventId: 'e1',
      title: 'Dentiste',
      body: '08:30 – 09:15',
      notificationId: 42,
      endsAt: DateTime.utc(2026, 11, 12, 8, 15),
    );
    final back = ReminderPayload.decode(payload.encode());
    expect(back.endsAt, DateTime.utc(2026, 11, 12, 8, 15));
    // Snoozed at 08:00 for 10 min: shown at 08:10 for 5 min.
    expect(
      back.lifetimeFrom(DateTime.utc(2026, 11, 12, 8, 10)),
      const Duration(minutes: 5),
    );
    // Snoozed past the end: not shown again.
    expect(back.lifetimeFrom(DateTime.utc(2026, 11, 12, 8, 20)), isNull);
  });

  test('notifications of older versions (no end) still work', () {
    final old = ReminderPayload.decode(
      '{"eventId":"e1","title":"T","body":"B","id":7}',
    );
    expect(old.endsAt, isNull);
    expect(old.lifetimeFrom(DateTime.utc(2026)), const Duration(days: 1));
  });
}
