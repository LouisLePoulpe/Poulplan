import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import 'geo.dart';
import 'polyline.dart';

enum TravelMode { car, bike, foot }

class RoutingException implements Exception {
  const RoutingException(this.message);

  final String message;

  @override
  String toString() => 'RoutingException: $message';
}

/// A computed route.
@immutable
class RouteResult {
  const RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  final int distanceMeters;
  final int durationSeconds;
  final List<GeoPoint> points;
}

/// `/route/v1/…?overview=full&geometries=polyline` response of OSRM.
RouteResult parseOsrmRoute(Map<String, dynamic> json) {
  final routes = json['routes'];
  if (json['code'] != 'Ok' || routes is! List || routes.isEmpty) {
    throw RoutingException('${json['message'] ?? json['code']}');
  }
  final route = routes.first as Map<String, dynamic>;
  return RouteResult(
    distanceMeters: (route['distance'] as num).round(),
    durationSeconds: (route['duration'] as num).round(),
    points: decodePolyline(route['geometry'] as String? ?? ''),
  );
}

/// BRouter track as GeoJSON (`format=geojson`).
RouteResult parseBrouterGeoJson(Map<String, dynamic> json) {
  final features = json['features'];
  if (features is! List || features.isEmpty) {
    throw const RoutingException('no track');
  }
  final feature = features.first as Map<String, dynamic>;
  final properties = feature['properties'] as Map<String, dynamic>? ?? {};
  final coordinates =
      (feature['geometry'] as Map<String, dynamic>?)?['coordinates'] as List? ??
      const [];
  int number(String key) => num.tryParse('${properties[key]}')?.round() ?? 0;
  return RouteResult(
    distanceMeters: number('track-length'),
    durationSeconds: number('total-time'),
    points: [
      for (final c in coordinates.cast<List<dynamic>>())
        GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ],
  );
}

/// « 4 min », « 1 h », « 1 h 31 ».
String formatDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0
      ? '${minutes ~/ 60} h'
      : '${minutes ~/ 60} h ${rest.toString().padLeft(2, '0')}';
}

/// « 850 m », « 12,3 km ».
String formatDistance(int meters) => meters < 1000
    ? '$meters m'
    : '${NumberFormat('#,##0.#', 'fr').format(meters / 1000)} km';
