import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/geo/geo_service.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/data/repositories/route_repository.dart';
import 'package:poulplan/data/sync/change_recorder.dart';
import 'package:poulplan/data/sync/entity_codecs.dart';
import 'package:poulplan/domain/geo/geo.dart';
import 'package:poulplan/domain/geo/polyline.dart';
import 'package:poulplan/domain/geo/routing.dart';
import 'package:poulplan/domain/sync/hlc.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const home = Place('Maison', GeoPoint(48.85, 2.29));
  const office = GeoPoint(48.86, 2.33);
  const result = RouteResult(
    distanceMeters: 3200,
    durationSeconds: 600,
    points: [GeoPoint(48.85, 2.29), GeoPoint(48.855, 2.31), office],
  );

  test('the coordinates of the place are kept with the event', () async {
    final events = EventRepository(db);
    final e = await events.create(
      title: 'Réunion',
      location: 'Bureau',
      placePoint: office,
      start: DateTime.utc(2026, 11, 10, 9),
      end: DateTime.utc(2026, 11, 10, 10),
      timeZone: 'UTC',
    );
    expect((await events.findById(e.id))!.placePoint, office);
    final fields = await codecFor('event').read(db, e.id);
    expect(fields!['latitude'], 48.86);
    await events.update(e.copyWith(placePoint: () => null));
    expect((await events.findById(e.id))!.placePoint, isNull);
  });

  test('a route is remembered, replaced and synchronized', () async {
    final recorder = ChangeRecorder(db, HlcClock('dev1'));
    final routes = RouteRepository(db, recorder: recorder);
    await routes.save(
      eventId: 'e1',
      mode: TravelMode.car,
      origin: home,
      destination: office,
      result: result,
      engine: 'osrm',
    );
    final second = await routes.save(
      eventId: 'e1',
      mode: TravelMode.bike,
      origin: home,
      destination: office,
      result: result,
      engine: 'brouter',
    );
    final stored = (await routes.findForEvent('e1'))!;
    expect(stored.id, second.id);
    expect(stored.mode, TravelMode.bike);
    expect(stored.result.points, result.points);
    expect(stored.originLabel, 'Maison');
    expect(await routes.findForEvent('e2'), isNull);
    final dirty = await (db.select(
      db.syncMeta,
    )..where((m) => m.entity.equals('route'))).get();
    expect(dirty, hasLength(2));
  });

  group('online services', () {
    test('address search: Nominatim with an identifying User-Agent', () async {
      late http.Request sent;
      final service = GeoService(
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode([
              {'display_name': 'Bureau, Paris', 'lat': '48.86', 'lon': '2.33'},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final places = await service.search('bureau paris');
      expect(places.single.point, office);
      expect(sent.url.host, 'nominatim.openstreetmap.org');
      expect(sent.url.queryParameters['q'], 'bureau paris');
      expect(sent.headers['User-Agent'], contains('Poulplan'));
    });

    test('searches are spaced by at least one second', () async {
      var now = DateTime(2026, 11, 4, 12);
      final waits = <Duration>[];
      final service = GeoService(
        client: MockClient((_) async => http.Response('[]', 200)),
        clock: () => now,
        wait: (d) async {
          waits.add(d);
          now = now.add(d);
        },
      );
      await service.search('a');
      now = now.add(const Duration(milliseconds: 300));
      await service.search('b');
      expect(waits, [const Duration(milliseconds: 700)]);
    });

    test('route: FOSSGIS OSRM server, profile by travel mode', () async {
      late http.Request sent;
      final service = GeoService(
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 3200,
                  'duration': 600,
                  'geometry': encodePolyline(result.points),
                },
              ],
            }),
            200,
          );
        }),
      );
      final route = await service.route(home.point, office, TravelMode.bike);
      expect(route.durationSeconds, 600);
      expect(sent.url.host, 'routing.openstreetmap.de');
      expect(
        sent.url.path,
        '/routed-bike/route/v1/driving/2.29,48.85;2.33,48.86',
      );
      expect(sent.url.queryParameters['geometries'], 'polyline');
      expect(sent.headers['User-Agent'], contains('Poulplan'));
    });

    test('network errors become a clear failure', () async {
      final service = GeoService(
        client: MockClient((_) async => http.Response('busy', 503)),
      );
      expect(
        () => service.route(home.point, office, TravelMode.car),
        throwsA(isA<RoutingException>()),
      );
    });
  });
}
