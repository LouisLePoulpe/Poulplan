// Fills a separate data directory with a demo calendar, for the README and
// store screenshots (never the real one):
//   dart run tool/demo_data.dart /tmp/poulplan-demo
//   POULPLAN_DATA_DIR=/tmp/poulplan-demo flutter run -d linux
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/geo/geo_service.dart';
import 'package:poulplan/data/repositories/birthday_repository.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/data/repositories/route_repository.dart';
import 'package:poulplan/domain/geo/geo.dart';
import 'package:poulplan/domain/geo/routing.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Same as `databaseFileName` (lib/data/db/connection.dart, Flutter only).
const databaseFileName = 'poulplan.db';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/demo_data.dart <directory>');
    exit(64);
  }
  tzdata.initializeTimeZones();
  final paris = tz.getLocation('Europe/Paris');
  final dir = Directory(args.single)..createSync(recursive: true);
  final file = File(p.join(dir.path, databaseFileName));
  if (file.existsSync()) file.deleteSync();
  final db = AppDatabase(NativeDatabase(file));
  final events = EventRepository(db);

  DateTime at(int month, int day, int hour, [int minute = 0]) =>
      tz.TZDateTime(paris, 2026, month, day, hour, minute).toUtc();

  Future<String> add(
    String title,
    DateTime start,
    DateTime end, {
    String? category,
    String? location,
    GeoPoint? point,
    String? rrule,
    bool allDay = false,
  }) async => (await events.create(
    title: title,
    categoryId: category,
    location: location,
    placePoint: point,
    start: start,
    end: end,
    allDay: allDay,
    timeZone: 'Europe/Paris',
    rrule: rrule,
  )).id;

  const work = 'default-work', personal = 'default-personal';
  const family = 'default-family', health = 'default-health';
  await add(
    'Réunion d\'équipe',
    at(11, 2, 9, 30),
    at(11, 2, 10, 30),
    category: work,
    rrule: 'FREQ=WEEKLY;BYDAY=MO',
  );
  await add(
    'Piscine',
    at(11, 3, 18),
    at(11, 3, 19),
    category: personal,
    location: 'Piscine du Rhône',
    rrule: 'FREQ=WEEKLY;BYDAY=TU,TH',
  );
  await add(
    'Cours de piano',
    at(11, 4, 17, 30),
    at(11, 4, 18, 30),
    category: personal,
    rrule: 'FREQ=WEEKLY;BYDAY=WE',
  );
  await add('Revue de projet', at(11, 10, 14), at(11, 10, 16), category: work);
  await add(
    'Déjeuner avec Paul',
    at(11, 10, 12, 15),
    at(11, 10, 13, 30),
    category: personal,
    location: 'Bouchon des Filles',
  );
  final dentist = await add(
    'Dentiste',
    at(11, 12, 8, 30),
    at(11, 12, 9, 15),
    category: health,
    location: 'Place Bellecour, Lyon',
    point: const GeoPoint(45.7577, 4.8324),
  );
  await add(
    'Présentation client',
    at(11, 12, 10),
    at(11, 12, 11, 30),
    category: work,
  );
  await add(
    'Atelier planning',
    at(11, 12, 10, 30),
    at(11, 12, 12),
    category: work,
  );
  await add(
    'Concert',
    at(11, 13, 20, 30),
    at(11, 13, 23),
    category: personal,
    location: 'Auditorium de Lyon',
  );
  await add(
    'Week-end à Annecy',
    DateTime.utc(2026, 11, 14),
    DateTime.utc(2026, 11, 16),
    category: family,
    allDay: true,
  );
  await add(
    'Rendre le rapport',
    DateTime.utc(2026, 11, 18),
    DateTime.utc(2026, 11, 19),
    category: work,
    allDay: true,
  );
  await add(
    'Vaccin grippe',
    at(11, 19, 11),
    at(11, 19, 11, 30),
    category: health,
  );
  await add(
    'Repas de famille',
    at(11, 22, 12),
    at(11, 22, 15),
    category: family,
  );
  await add(
    'Salon du livre',
    DateTime.utc(2026, 11, 26),
    DateTime.utc(2026, 11, 29),
    category: personal,
    allDay: true,
  );

  final birthdays = BirthdayRepository(db);
  await birthdays.create(name: 'Léa', month: 11, day: 11, birthYear: 1996);
  await birthdays.create(name: 'Grand-mère', month: 11, day: 24);

  // A remembered route (computed online, like in the app).
  try {
    const start = Place('Gare de la Part-Dieu', GeoPoint(45.7605, 4.8593));
    final route = await GeoService().route(
      start.point,
      const GeoPoint(45.7577, 4.8324),
      TravelMode.bike,
    );
    await RouteRepository(db).save(
      eventId: dentist,
      mode: TravelMode.bike,
      origin: start,
      destination: const GeoPoint(45.7577, 4.8324),
      result: route,
      engine: 'osrm',
    );
  } catch (e) {
    stderr.writeln('No route (offline?): $e');
  }
  await db.close();
  stdout.writeln('Demo calendar written to ${file.path}');
}
