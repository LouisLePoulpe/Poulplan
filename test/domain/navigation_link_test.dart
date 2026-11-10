import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/geo/geo.dart';
import 'package:poulplan/domain/geo/navigation_link.dart';

void main() {
  test('geo: link with coordinates and the name of the event', () {
    expect(
      geoUri(point: const GeoPoint(45.7577, 4.8324), label: 'Dentiste (Lyon)'),
      Uri.parse('geo:45.7577,4.8324?q=45.7577,4.8324(Dentiste%20Lyon)'),
    );
  });

  test('geo: link with only an address', () {
    expect(
      geoUri(address: 'Place Bellecour, Lyon'),
      Uri.parse('geo:0,0?q=Place%20Bellecour%2C%20Lyon'),
    );
  });

  test('nothing to navigate to', () {
    expect(geoUri(address: '  '), isNull);
    expect(webDirectionsUri(address: ''), isNull);
  });

  test('OpenStreetMap in the browser (Linux)', () {
    expect(
      webDirectionsUri(point: const GeoPoint(45.7577, 4.8324)),
      Uri.parse('https://www.openstreetmap.org/directions?to=45.7577%2C4.8324'),
    );
    expect(
      webDirectionsUri(address: 'Place Bellecour, Lyon'),
      Uri.parse(
        'https://www.openstreetmap.org/search?query=Place+Bellecour%2C+Lyon',
      ),
    );
  });
}
