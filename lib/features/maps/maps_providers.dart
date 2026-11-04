import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../data/geo/geo_service.dart';
import '../../data/maps/map_tiles.dart';
import '../../data/providers.dart';
import '../../domain/geo/geo.dart';
import '../../domain/geo/stored_route.dart';

final geoServiceProvider = Provider((ref) => GeoService());

final routeForEventProvider = StreamProvider.family<StoredRoute?, String>(
  (ref, eventId) => ref.watch(routeRepositoryProvider).watchForEvent(eventId),
);

final mapTileStoreProvider = Provider(
  (ref) => MapTileStore(
    Directory(p.join(ref.watch(appDirectoryProvider).path, 'maps')),
  ),
);

final mapZoneRepositoryProvider = Provider(
  (ref) => MapZoneRepository(
    ref.watch(databaseProvider),
    ref.watch(mapTileStoreProvider),
  ),
);

final mapZonesProvider = StreamProvider<List<MapZone>>(
  (ref) => ref.watch(mapZoneRepositoryProvider).watchAll(),
);

const _templateKey = 'map_tile_template';

/// OpenFreeMap tile URL template; the last known one when offline.
final tileTemplateProvider = FutureProvider<String?>((ref) async {
  final settings = ref.read(settingsRepositoryProvider);
  final client = http.Client();
  try {
    final template = await fetchTileTemplate(client);
    await settings.setValue(_templateKey, template);
    return template;
  } catch (_) {
    return settings.getValue(_templateKey);
  } finally {
    client.close();
  }
});

/// The map style (OpenFreeMap « liberty », French labels), its tiles
/// served by [LocalFirstTileProvider]. Fails offline before the style was
/// ever loaded: the map then shows the route on a plain background.
final mapStyleProvider = FutureProvider<vt.Style>((ref) async {
  final store = ref.watch(mapTileStoreProvider);
  await ref.read(mapZoneRepositoryProvider).refreshStore();
  unawaited(store.trimCache().catchError((Object _) {}));
  final template = await ref.watch(tileTemplateProvider.future);
  final style = await vt.StyleReader(
    uri: OpenFreeMap.styleUrl,
    language: 'fr',
    headers: const {'User-Agent': GeoService.userAgent},
    cachePath: () async => p.join(store.root.path, 'style'),
    resolveProvider: (id) async => id == OpenFreeMap.sourceId
        ? LocalFirstTileProvider(store, urlTemplate: template)
        : null,
  ).read();
  ref.onDispose(style.dispose);
  return style;
});

const _homeKey = 'home_place';

/// Starting point of the routes (« Adresse de départ »), on this device.
final homePlaceProvider = NotifierProvider<HomePlaceController, Place?>(
  HomePlaceController.new,
);

class HomePlaceController extends Notifier<Place?> {
  @override
  Place? build() {
    ref.read(settingsRepositoryProvider).getValue(_homeKey).then((raw) {
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = Place(
        json['label'] as String,
        GeoPoint(
          (json['lat'] as num).toDouble(),
          (json['lon'] as num).toDouble(),
        ),
      );
    });
    return null;
  }

  Future<void> set(Place? place) async {
    await ref
        .read(settingsRepositoryProvider)
        .setValue(
          _homeKey,
          place == null
              ? ''
              : jsonEncode({
                  'label': place.label,
                  'lat': place.point.latitude,
                  'lon': place.point.longitude,
                }),
        );
    state = place;
  }
}
