import 'dart:math';

import 'geo.dart';

/// Web Mercator tile (« slippy map ») containing [p] at [zoom].
({int x, int y}) tileOf(GeoPoint p, int zoom) {
  final n = 1 << zoom;
  final lat = p.latitude.clamp(-85.0511, 85.0511) * pi / 180;
  final x = ((p.longitude + 180) / 360 * n).floor().clamp(0, n - 1);
  final y = ((1 - log(tan(lat) + 1 / cos(lat)) / pi) / 2 * n).floor().clamp(
    0,
    n - 1,
  );
  return (x: x, y: y);
}

typedef TileId = ({int z, int x, int y});

({int minX, int maxX, int minY, int maxY}) _range(GeoBounds b, int z) {
  final nw = tileOf(GeoPoint(b.north, b.west), z);
  final se = tileOf(GeoPoint(b.south, b.east), z);
  return (minX: nw.x, maxX: se.x, minY: nw.y, maxY: se.y);
}

/// Tiles covering [bounds], from [minZoom] to [maxZoom].
Iterable<TileId> tilesIn(
  GeoBounds bounds, {
  required int minZoom,
  required int maxZoom,
}) sync* {
  for (var z = minZoom; z <= maxZoom; z++) {
    final r = _range(bounds, z);
    for (var x = r.minX; x <= r.maxX; x++) {
      for (var y = r.minY; y <= r.maxY; y++) {
        yield (z: z, x: x, y: y);
      }
    }
  }
}

int countTiles(GeoBounds bounds, {required int minZoom, required int maxZoom}) {
  var count = 0;
  for (var z = minZoom; z <= maxZoom; z++) {
    final r = _range(bounds, z);
    count += (r.maxX - r.minX + 1) * (r.maxY - r.minY + 1);
  }
  return count;
}
