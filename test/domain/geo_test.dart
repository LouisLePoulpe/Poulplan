import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/geo/geo.dart';
import 'package:poulplan/domain/geo/polyline.dart';
import 'package:poulplan/domain/geo/routing.dart';
import 'package:poulplan/domain/geo/tiles.dart';

void main() {
  group('polyline', () {
    test('decodes the reference example (precision 5)', () {
      // Example of the Google polyline algorithm documentation.
      expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), const [
        GeoPoint(38.5, -120.2),
        GeoPoint(40.7, -120.95),
        GeoPoint(43.252, -126.453),
      ]);
    });

    test('encoding then decoding gives the points back', () {
      const points = [
        GeoPoint(48.85837, 2.29448),
        GeoPoint(48.86061, 2.33764),
        GeoPoint(45.76404, 4.83566),
      ];
      expect(decodePolyline(encodePolyline(points)), points);
      expect(decodePolyline(''), isEmpty);
    });
  });

  group('tiles', () {
    test('tile of a point', () {
      // Paris, zoom 14.
      expect(tileOf(const GeoPoint(48.8566, 2.3522), 14), (x: 8299, y: 5636));
      expect(tileOf(const GeoPoint(0, 0), 0), (x: 0, y: 0));
    });

    test('tiles covering an area, every zoom', () {
      const area = GeoBounds(
        south: 48.80,
        west: 2.25,
        north: 48.90,
        east: 2.42,
      );
      final tiles = tilesIn(area, minZoom: 0, maxZoom: 14).toList();
      expect(tiles.length, countTiles(area, minZoom: 0, maxZoom: 14));
      expect(tiles.where((t) => t.z == 0), hasLength(1));
      expect(tiles.toSet(), hasLength(tiles.length));
      final z14 = tiles.where((t) => t.z == 14).toList();
      expect(z14, hasLength(countTiles(area, minZoom: 14, maxZoom: 14)));
      expect(z14.length, inInclusiveRange(40, 120));
    });

    test('bounds around a point', () {
      final b = GeoBounds.around(const GeoPoint(45, 5), kilometers: 10);
      expect(b.contains(const GeoPoint(45, 5)), isTrue);
      expect(b.north - b.south, closeTo(20 / 111.2, 0.01));
      expect(b.contains(const GeoPoint(45.2, 5)), isFalse);
    });
  });

  group('routing responses', () {
    test('OSRM route', () {
      final route = parseOsrmRoute({
        'code': 'Ok',
        'routes': [
          {
            'distance': 12345.6,
            'duration': 901.2,
            'geometry': encodePolyline(const [
              GeoPoint(48.85, 2.29),
              GeoPoint(48.86, 2.33),
            ]),
          },
        ],
      });
      expect(route.distanceMeters, 12346);
      expect(route.durationSeconds, 901);
      expect(route.points, const [
        GeoPoint(48.85, 2.29),
        GeoPoint(48.86, 2.33),
      ]);
    });

    test('OSRM failure', () {
      expect(
        () => parseOsrmRoute({'code': 'NoRoute', 'message': 'Impossible'}),
        throwsA(isA<RoutingException>()),
      );
    });

    test('BRouter GeoJSON track', () {
      final route = parseBrouterGeoJson({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'track-length': '5321', 'total-time': '720'},
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [2.29, 48.85, 35.0],
                [2.33, 48.86, 40.0],
              ],
            },
          },
        ],
      });
      expect(route.distanceMeters, 5321);
      expect(route.durationSeconds, 720);
      expect(route.points.last, const GeoPoint(48.86, 2.33));
    });

    test('BRouter GPX track (older BRouter versions)', () {
      final route = parseBrouterTrack('''<?xml version="1.0" encoding="UTF-8"?>
<!-- track-length = 1803 filtered ascend = 3 plain-ascend = -2 cost=2384 energy=.0kwh time=1h 3m 21s -->
<gpx><trk><trkseg>
<trkpt lon="2.290000" lat="48.850000"><ele>35</ele></trkpt>
<trkpt lon="2.330000" lat="48.860000"><ele>40</ele></trkpt>
</trkseg></trk></gpx>''');
      expect(route.distanceMeters, 1803);
      expect(route.durationSeconds, 3600 + 3 * 60 + 21);
      expect(route.points, const [
        GeoPoint(48.85, 2.29),
        GeoPoint(48.86, 2.33),
      ]);
      expect(
        parseBrouterTrack(
          '{"type":"FeatureCollection","features":[{"properties":'
          '{"track-length":"10","total-time":"5"},"geometry":'
          '{"coordinates":[[2.29,48.85],[2.33,48.86]]}}]}',
        ).durationSeconds,
        5,
      );
      expect(
        () => parseBrouterTrack('datafile E0_N45.rd5 not found'),
        throwsA(isA<RoutingException>()),
      );
    });

    test('travel time text', () {
      expect(formatDuration(240), '4 min');
      expect(formatDuration(3600), '1 h');
      expect(formatDuration(5460), '1 h 31');
      expect(formatDistance(850), '850 m');
      expect(formatDistance(12346), '12,3 km');
    });
  });

  test('Nominatim results', () {
    final places = parseNominatim([
      {
        'display_name': 'Tour Eiffel, Paris, France',
        'lat': '48.8582599',
        'lon': '2.2945006',
      },
      {'display_name': 'Sans coordonnées'},
    ]);
    expect(places.single.label, 'Tour Eiffel, Paris, France');
    expect(places.single.point, const GeoPoint(48.8582599, 2.2945006));
  });
}
