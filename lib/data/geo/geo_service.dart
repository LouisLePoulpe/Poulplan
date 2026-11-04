import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo/geo.dart';
import '../../domain/geo/routing.dart';

/// Online address search (Nominatim) and routes (OSRM of FOSSGIS), within
/// their usage policies: identifying User-Agent, at most one search per
/// second, searches only on an explicit action (no autocomplete).
class GeoService {
  GeoService({
    http.Client? client,
    DateTime Function()? clock,
    Future<void> Function(Duration)? wait,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed;

  final http.Client _client;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _wait;
  DateTime? _lastSearch;

  static const userAgent =
      'Poulplan (calendrier libre; +https://github.com/LouisLePoulpe/Poulplan)';
  static const _headers = {'User-Agent': userAgent};
  static const _timeout = Duration(seconds: 20);

  Future<List<Place>> search(String query) async {
    final last = _lastSearch;
    if (last != null) {
      final elapsed = _clock().difference(last);
      if (elapsed < const Duration(seconds: 1)) {
        await _wait(const Duration(seconds: 1) - elapsed);
      }
    }
    _lastSearch = _clock();
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '6',
      'accept-language': 'fr',
    });
    final response = await _client
        .get(url, headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw RoutingException('Nominatim ${response.statusCode}');
    }
    return parseNominatim(
      jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>,
    );
  }

  static const _profiles = {
    TravelMode.car: 'routed-car',
    TravelMode.bike: 'routed-bike',
    TravelMode.foot: 'routed-foot',
  };

  Future<RouteResult> route(GeoPoint from, GeoPoint to, TravelMode mode) async {
    String coordinates(GeoPoint p) => '${p.longitude},${p.latitude}';
    final url = Uri.https(
      'routing.openstreetmap.de',
      '/${_profiles[mode]}/route/v1/driving/'
          '${coordinates(from)};${coordinates(to)}',
      {'overview': 'full', 'geometries': 'polyline'},
    );
    final http.Response response;
    try {
      response = await _client.get(url, headers: _headers).timeout(_timeout);
    } catch (e) {
      throw RoutingException('$e');
    }
    if (response.statusCode != 200) {
      throw RoutingException('OSRM ${response.statusCode}');
    }
    return parseOsrmRoute(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
