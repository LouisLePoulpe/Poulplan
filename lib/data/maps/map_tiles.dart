import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/geo/geo.dart';
import '../../domain/geo/tiles.dart';
import '../db/app_database.dart';
import '../geo/geo_service.dart';

/// OpenFreeMap: style and vector tiles (OpenMapTiles schema), no key.
class OpenFreeMap {
  static const styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
  static const tileJsonUrl = 'https://tiles.openfreemap.org/planet';
  static const sourceId = 'openmaptiles';
  static const maxZoom = 14;

  /// Shown after « © » by the map's attribution widget.
  static const attribution = 'OpenFreeMap © OpenMapTiles © OpenStreetMap';
}

/// Tiles on this device: downloaded zones (kept until deleted) and the
/// tiles of the places already seen (a cache with a size limit).
class MapTileStore {
  MapTileStore(this.root);

  final Directory root;

  /// Zones whose download is complete, refreshed by [loadZones].
  List<String> _zones = const [];

  Directory get _cache => Directory(p.join(root.path, 'cache'));

  Directory zoneDirectory(String zoneId) =>
      Directory(p.join(root.path, 'zones', zoneId));

  File _tile(Directory dir, int z, int x, int y) =>
      File(p.join(dir.path, '$z', '$x', '$y.pbf'));

  File zoneTile(String zoneId, TileId t) =>
      _tile(zoneDirectory(zoneId), t.z, t.x, t.y);

  void useZones(List<String> zoneIds) => _zones = List.of(zoneIds);

  Future<Uint8List?> read(int z, int x, int y) async {
    for (final zone in _zones) {
      final file = _tile(zoneDirectory(zone), z, x, y);
      if (file.existsSync()) return file.readAsBytes();
    }
    final cached = _tile(_cache, z, x, y);
    if (cached.existsSync()) return cached.readAsBytes();
    return null;
  }

  Future<void> remember(int z, int x, int y, List<int> bytes) async {
    final file = _tile(_cache, z, x, y);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  /// Keeps the tile cache under [maxBytes], removing the oldest tiles.
  Future<void> trimCache({int maxBytes = 150 * 1024 * 1024}) async {
    if (!_cache.existsSync()) return;
    final files = <(File, FileStat)>[];
    await for (final e in _cache.list(recursive: true)) {
      if (e is File) files.add((e, await e.stat()));
    }
    var total = files.fold<int>(0, (sum, f) => sum + f.$2.size);
    if (total <= maxBytes) return;
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    for (final (file, stat) in files) {
      if (total <= maxBytes) break;
      await file.delete();
      total -= stat.size;
    }
  }

  Future<int> cacheBytes() async {
    if (!_cache.existsSync()) return 0;
    var total = 0;
    await for (final e in _cache.list(recursive: true)) {
      if (e is File) total += await e.length();
    }
    return total;
  }
}

/// Tile source of the map: the device first (zones, cache), then the
/// network, whose tiles are kept in the cache.
class LocalFirstTileProvider extends vt.VectorTileProvider {
  LocalFirstTileProvider(this._store, {this.urlTemplate, http.Client? client})
    : _client = client ?? http.Client();

  final MapTileStore _store;
  final String? urlTemplate;
  final http.Client _client;

  @override
  int get maximumZoom => OpenFreeMap.maxZoom;

  @override
  int get minimumZoom => 0;

  @override
  String get cacheKey => 'poulplan-local-first';

  /// The store is already on disk.
  @override
  bool get cacheBytesToDisk => false;

  @override
  Future<vt.TileResponse> load(
    vt.TileKey tile, {
    vt.CancellationToken? cancellation,
  }) async {
    final local = await _store.read(tile.z, tile.x, tile.y);
    if (local != null) return vt.TileResponseData(local);
    final template = urlTemplate;
    if (template == null) return const vt.TileResponseNotFound();
    try {
      final response = await _client.get(
        Uri.parse(tileUrl(template, (z: tile.z, x: tile.x, y: tile.y))),
        headers: const {'User-Agent': GeoService.userAgent},
      );
      if (response.statusCode == 404 || response.statusCode == 204) {
        return const vt.TileResponseNotFound();
      }
      if (response.statusCode != 200) {
        return vt.TileResponseError('HTTP ${response.statusCode}');
      }
      await _store.remember(tile.z, tile.x, tile.y, response.bodyBytes);
      return vt.TileResponseData(response.bodyBytes);
    } catch (e) {
      return vt.TileResponseError(e);
    }
  }

  @override
  void dispose() => _client.close();
}

String tileUrl(String template, TileId t) => template
    .replaceAll('{z}', '${t.z}')
    .replaceAll('{x}', '${t.x}')
    .replaceAll('{y}', '${t.y}');

/// Tile URL template of OpenFreeMap (it changes with each data release),
/// read from its TileJSON.
Future<String> fetchTileTemplate(http.Client client) async {
  final response = await client
      .get(
        Uri.parse(OpenFreeMap.tileJsonUrl),
        headers: const {'User-Agent': GeoService.userAgent},
      )
      .timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    throw HttpException('TileJSON ${response.statusCode}');
  }
  final json = jsonDecode(utf8.decode(response.bodyBytes));
  return ((json as Map<String, dynamic>)['tiles'] as List).first as String;
}

/// A zone of the map kept on this device.
class MapZone {
  const MapZone({
    required this.id,
    required this.name,
    required this.bounds,
    required this.tileCount,
    required this.bytes,
    this.downloadedAt,
  });

  final String id;
  final String name;
  final GeoBounds bounds;
  final int tileCount;
  final int bytes;
  final DateTime? downloadedAt;

  bool get complete => downloadedAt != null;
}

/// Largest zone that can be downloaded (tiles, all zooms).
const maxZoneTiles = 6000;

/// Downloaded zones: list, download (resumable), delete.
class MapZoneRepository {
  MapZoneRepository(this._db, this.store, {http.Client? client})
    : _client = client ?? http.Client();

  final AppDatabase _db;
  final MapTileStore store;
  final http.Client _client;

  static MapZone _toZone(MapZoneRow r) => MapZone(
    id: r.id,
    name: r.name,
    bounds: GeoBounds(
      south: r.south,
      west: r.west,
      north: r.north,
      east: r.east,
    ),
    tileCount: r.tileCount,
    bytes: r.bytes,
    downloadedAt: r.downloadedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.downloadedAt!),
  );

  Stream<List<MapZone>> watchAll() =>
      (_db.select(_db.mapZones)..orderBy([(z) => OrderingTerm.asc(z.name)]))
          .watch()
          .map((rows) => rows.map(_toZone).toList());

  /// Serves the complete zones from the tile store.
  Future<void> refreshStore() async {
    final rows = await (_db.select(
      _db.mapZones,
    )..where((z) => z.downloadedAt.isNotNull())).get();
    store.useZones(rows.map((r) => r.id).toList());
  }

  Future<MapZone> create(String name, GeoBounds bounds) async {
    final count = countTiles(bounds, minZoom: 0, maxZoom: OpenFreeMap.maxZoom);
    if (count > maxZoneTiles) throw ArgumentError('zone too large: $count');
    final id = const Uuid().v4();
    await _db
        .into(_db.mapZones)
        .insert(
          MapZonesCompanion.insert(
            id: id,
            name: name,
            south: bounds.south,
            west: bounds.west,
            north: bounds.north,
            east: bounds.east,
            maxZoom: OpenFreeMap.maxZoom,
            tileCount: count,
          ),
        );
    return _toZone(
      await (_db.select(
        _db.mapZones,
      )..where((z) => z.id.equals(id))).getSingle(),
    );
  }

  /// Downloads the missing tiles of [zone] ([progress]: done, total).
  /// Two requests at a time, as tile servers ask. Throws when the network
  /// fails; calling it again resumes.
  Future<void> download(
    MapZone zone, {
    required String urlTemplate,
    void Function(int done, int total)? progress,
  }) async {
    final tiles = tilesIn(
      zone.bounds,
      minZoom: 0,
      maxZoom: OpenFreeMap.maxZoom,
    ).toList();
    var done = 0;
    var bytes = 0;
    var index = 0;
    Future<void> worker() async {
      while (index < tiles.length) {
        final t = tiles[index++];
        final file = store.zoneTile(zone.id, t);
        if (!file.existsSync()) {
          final response = await _client
              .get(
                Uri.parse(tileUrl(urlTemplate, t)),
                headers: const {'User-Agent': GeoService.userAgent},
              )
              .timeout(const Duration(seconds: 30));
          if (response.statusCode == 200) {
            await file.parent.create(recursive: true);
            await file.writeAsBytes(response.bodyBytes);
          } else if (response.statusCode != 404 && response.statusCode != 204) {
            throw HttpException('tile ${response.statusCode}');
          }
        }
        if (file.existsSync()) bytes += await file.length();
        progress?.call(++done, tiles.length);
      }
    }

    await Future.wait([worker(), worker()]);
    await (_db.update(_db.mapZones)..where((z) => z.id.equals(zone.id))).write(
      MapZonesCompanion(
        bytes: Value(bytes),
        downloadedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    await refreshStore();
  }

  Future<void> delete(String id) async {
    final dir = store.zoneDirectory(id);
    if (dir.existsSync()) await dir.delete(recursive: true);
    await (_db.delete(_db.mapZones)..where((z) => z.id.equals(id))).go();
    await refreshStore();
  }
}
