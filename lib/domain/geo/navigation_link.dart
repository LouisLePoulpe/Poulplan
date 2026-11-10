import 'geo.dart';

/// `geo:` link (RFC 5870, with the `q` parameter understood by Android
/// navigation apps): the coordinates when known, else the address.
Uri? geoUri({GeoPoint? point, String? address, String? label}) {
  if (point != null) {
    final coordinates = '${point.latitude},${point.longitude}';
    // Brackets end the label: keep them out of it.
    final name = label?.replaceAll(RegExp(r'[()]'), '').trim();
    final query = name == null || name.isEmpty
        ? coordinates
        : '$coordinates(${Uri.encodeComponent(name)})';
    return Uri.parse('geo:$coordinates?q=$query');
  }
  final text = address?.trim() ?? '';
  if (text.isEmpty) return null;
  return Uri.parse('geo:0,0?q=${Uri.encodeComponent(text)}');
}

/// Route to the place on openstreetmap.org (Linux: no navigation app).
Uri? webDirectionsUri({GeoPoint? point, String? address}) {
  if (point != null) {
    return Uri.https('www.openstreetmap.org', '/directions', {
      'to': '${point.latitude},${point.longitude}',
    });
  }
  final text = address?.trim() ?? '';
  if (text.isEmpty) return null;
  return Uri.https('www.openstreetmap.org', '/search', {'query': text});
}
