import 'geo.dart';

/// Google « encoded polyline » (precision 5), as returned by OSRM; also the
/// compact form routes are stored in.
List<GeoPoint> decodePolyline(String encoded) {
  final points = <GeoPoint>[];
  var index = 0, lat = 0, lon = 0;
  int next() {
    var result = 0, shift = 0, b = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += next();
    lon += next();
    points.add(GeoPoint(lat / 1e5, lon / 1e5));
  }
  return points;
}

String encodePolyline(List<GeoPoint> points) {
  final out = StringBuffer();
  void write(int value) {
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }

  var lastLat = 0, lastLon = 0;
  for (final p in points) {
    final lat = (p.latitude * 1e5).round();
    final lon = (p.longitude * 1e5).round();
    write(lat - lastLat);
    write(lon - lastLon);
    lastLat = lat;
    lastLon = lon;
  }
  return out.toString();
}
