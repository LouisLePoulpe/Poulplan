import '../../../data/repositories/event_repository.dart';
import '../../../domain/calendar/day.dart';

/// Debug helper: fills the month around [today] with sample events.
Future<void> insertDemoEvents(
  EventRepository repository,
  Day today,
  String zone,
) async {
  DateTime at(Day day, int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  await repository.create(
    title: "Réunion d'équipe",
    categoryId: 'default-work',
    start: at(today, 9),
    end: at(today, 10),
    timeZone: zone,
  );
  await repository.create(
    title: 'Dentiste',
    categoryId: 'default-health',
    start: at(today.addDays(2), 14, 30),
    end: at(today.addDays(2), 15, 15),
    timeZone: zone,
  );
  final holidayStart = today.addDays(5);
  await repository.create(
    title: 'Week-end en famille',
    categoryId: 'default-family',
    allDay: true,
    start: holidayStart.toUtcMidnight(),
    end: holidayStart.addDays(3).toUtcMidnight(),
    timeZone: zone,
  );
  await repository.create(
    title: 'Concert',
    categoryId: 'default-personal',
    start: at(today.addDays(-3), 21),
    end: at(today.addDays(-2), 1),
    timeZone: zone,
  );
  for (var i = 0; i < 5; i++) {
    await repository.create(
      title: 'Tâche ${i + 1}',
      start: at(today.addDays(8), 8 + i),
      end: at(today.addDays(8), 9 + i),
      timeZone: zone,
    );
  }
}
