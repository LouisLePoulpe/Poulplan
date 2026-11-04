import 'package:meta/meta.dart';

import 'geo.dart';
import 'routing.dart';

/// A route remembered for an event: readable offline, recomputable.
@immutable
class StoredRoute {
  const StoredRoute({
    required this.id,
    required this.eventId,
    required this.mode,
    required this.originLabel,
    required this.origin,
    required this.destination,
    required this.result,
    required this.engine,
    required this.computedAt,
  });

  final String id;
  final String eventId;
  final TravelMode mode;
  final String originLabel;
  final GeoPoint origin;
  final GeoPoint destination;
  final RouteResult result;

  /// `osrm` (online) or `brouter` (offline).
  final String engine;
  final DateTime computedAt;
}
