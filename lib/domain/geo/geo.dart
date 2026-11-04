import 'dart:math';

import 'package:meta/meta.dart';

/// A WGS 84 position.
@immutable
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// A place found by the address search.
@immutable
class Place {
  const Place(this.label, this.point);

  final String label;
  final GeoPoint point;
}

@immutable
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// A square of about 2 × [kilometers] around [center].
  factory GeoBounds.around(GeoPoint center, {required double kilometers}) {
    final dLat = kilometers / 111.2;
    final dLon = kilometers / (111.2 * cos(center.latitude * pi / 180));
    return GeoBounds(
      south: center.latitude - dLat,
      west: center.longitude - dLon,
      north: center.latitude + dLat,
      east: center.longitude + dLon,
    );
  }

  final double south;
  final double west;
  final double north;
  final double east;

  GeoPoint get center => GeoPoint((south + north) / 2, (west + east) / 2);

  bool contains(GeoPoint p) =>
      p.latitude >= south &&
      p.latitude <= north &&
      p.longitude >= west &&
      p.longitude <= east;

  Map<String, double> toJson() => {
    'south': south,
    'west': west,
    'north': north,
    'east': east,
  };

  factory GeoBounds.fromJson(Map<String, dynamic> json) => GeoBounds(
    south: (json['south'] as num).toDouble(),
    west: (json['west'] as num).toDouble(),
    north: (json['north'] as num).toDouble(),
    east: (json['east'] as num).toDouble(),
  );
}

/// Results of a Nominatim search (`format=jsonv2`); entries without
/// coordinates are skipped.
List<Place> parseNominatim(List<dynamic> json) => [
  for (final item in json.cast<Map<String, dynamic>>())
    if (double.tryParse('${item['lat']}') case final lat?)
      if (double.tryParse('${item['lon']}') case final lon?)
        Place(item['display_name'] as String? ?? '', GeoPoint(lat, lon)),
];
