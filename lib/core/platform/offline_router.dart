import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/geo/geo.dart';
import '../../domain/geo/routing.dart';

/// Offline routes through the BRouter app (Android, when installed).
class OfflineRouter {
  static const _channel = MethodChannel('org.poulapp.poulplan/brouter');

  static Future<bool> available() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return false;
    }
  }

  static const _vehicles = {
    TravelMode.car: 'motorcar',
    TravelMode.bike: 'bicycle',
    TravelMode.foot: 'foot',
  };

  static Future<RouteResult> route(
    GeoPoint from,
    GeoPoint to,
    TravelMode mode,
  ) async {
    try {
      final answer = await _channel.invokeMethod<String>('route', {
        'lats': [from.latitude, to.latitude],
        'lons': [from.longitude, to.longitude],
        'vehicle': _vehicles[mode],
      });
      return parseBrouterTrack(answer ?? '');
    } on PlatformException catch (e) {
      throw RoutingException(e.message ?? e.code);
    }
  }
}
