import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/maps/map_tiles.dart';
import '../../../domain/geo/geo.dart';
import '../maps_providers.dart';

LatLng toLatLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

/// The map: OpenFreeMap background (zones and seen places offline), an
/// optional route, the destination and the start.
class PoulplanMap extends ConsumerWidget {
  const PoulplanMap({
    super.key,
    this.destination,
    this.origin,
    this.route = const [],
    this.interactive = true,
    this.controller,
    this.onTap,
    this.onMoved,
  });

  final GeoPoint? destination;
  final GeoPoint? origin;
  final List<GeoPoint> route;
  final bool interactive;
  final MapController? controller;
  final VoidCallback? onTap;

  /// The visible area, after each move (and when the map is ready).
  final ValueChanged<GeoBounds>? onMoved;

  static GeoBounds _bounds(MapCamera camera) {
    final b = camera.visibleBounds;
    return GeoBounds(
      south: b.south,
      west: b.west,
      north: b.north,
      east: b.east,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(mapStyleProvider);
    final scheme = Theme.of(context).colorScheme;
    final points = [...route, ?destination, ?origin].map(toLatLng).toList();
    final fit = points.length >= 2
        ? CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(32),
            maxZoom: 16,
          )
        : null;
    Widget pin(IconData icon, Color color) => Icon(
      icon,
      color: color,
      size: 36,
      shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
    );

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCameraFit: fit,
        initialCenter: points.isEmpty ? const LatLng(46.6, 2.4) : points.first,
        initialZoom: points.isEmpty ? 5 : 14,
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: onTap == null ? null : (_, _) => onTap!(),
        onPositionChanged: onMoved == null
            ? null
            : (camera, _) => onMoved!(_bounds(camera)),
        onMapReady: onMoved == null || controller == null
            ? null
            : () => onMoved!(_bounds(controller!.camera)),
      ),
      children: [
        switch (style) {
          AsyncData(:final value) => vt.VectorTileLayer(
            theme: value.theme,
            tileProviders: value.providers,
            rasterSources: value.rasterSources,
            sprites: value.sprites,
            glyphs: value.glyphs,
          ),
          _ => ColoredBox(color: scheme.surfaceContainerHighest),
        },
        if (route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.map(toLatLng).toList(),
                strokeWidth: 5,
                color: const Color(0xFF8F6400),
                borderStrokeWidth: 2,
                borderColor: const Color(0xFFFFE600),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (origin != null)
              Marker(
                point: toLatLng(origin!),
                width: 36,
                height: 36,
                child: pin(Icons.trip_origin, scheme.primary),
              ),
            if (destination != null)
              Marker(
                point: toLatLng(destination!),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: pin(Icons.place, const Color(0xFFE53935)),
              ),
          ],
        ),
        // Compact (and wrapping) so that it fits small maps and phones.
        Align(
          alignment: Alignment.bottomRight,
          child: ColoredBox(
            color: scheme.surface.withValues(alpha: 0.75),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                '© ${OpenFreeMap.attribution}',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
