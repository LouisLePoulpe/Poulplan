import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/maps/map_tiles.dart';
import 'package:poulplan/domain/geo/geo.dart';
import 'package:poulplan/domain/geo/tiles.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late MapTileStore store;
  var requests = 0;
  var offline = false;

  final client = MockClient((request) async {
    if (offline) throw const SocketException('offline');
    requests++;
    expect(request.headers['User-Agent'], contains('Poulplan'));
    return http.Response.bytes(request.url.path.codeUnits, 200);
  });
  const template = 'https://tiles.example/{z}/{x}/{y}.pbf';
  // About 1 km around a point: a few dozen tiles at every zoom.
  final small = GeoBounds.around(const GeoPoint(48.85, 2.35), kilometers: 1);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('poulplan_tiles');
    store = MapTileStore(dir);
    requests = 0;
    offline = false;
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('a zone is downloaded once, then served offline', () async {
    final zones = MapZoneRepository(db, store, client: client);
    final zone = await zones.create('Paris', small);
    final total = countTiles(small, minZoom: 0, maxZoom: 14);
    expect(zone.tileCount, total);
    var last = 0;
    await zones.download(
      zone,
      urlTemplate: template,
      progress: (done, _) => last = done,
    );
    expect(requests, total);
    expect(last, total);
    final saved = (await zones.watchAll().first).single;
    expect(saved.complete, isTrue);
    expect(saved.bytes, greaterThan(0));

    // Again: nothing to download.
    await zones.download(zone, urlTemplate: template);
    expect(requests, total);

    offline = true;
    final provider = LocalFirstTileProvider(
      store,
      urlTemplate: template,
      client: client,
    );
    final t = tileOf(small.center, 14);
    final response = await provider.load(vt.TileKey(14, t.x, t.y));
    expect(response, isA<vt.TileResponseData>());

    await zones.delete(zone.id);
    expect(store.zoneDirectory(zone.id).existsSync(), isFalse);
    expect(
      await provider.load(vt.TileKey(14, t.x, t.y)),
      isA<vt.TileResponseError>(),
    );
  });

  test('a zone that is too large is refused', () async {
    final zones = MapZoneRepository(db, store, client: client);
    final france = GeoBounds.around(const GeoPoint(46.5, 2.5), kilometers: 400);
    expect(() => zones.create('France', france), throwsArgumentError);
  });

  test('tiles seen online are kept for offline use, within a limit', () async {
    final provider = LocalFirstTileProvider(
      store,
      urlTemplate: template,
      client: client,
    );
    expect(
      await provider.load(const vt.TileKey(10, 518, 352)),
      isA<vt.TileResponseData>(),
    );
    offline = true;
    expect(
      await provider.load(const vt.TileKey(10, 518, 352)),
      isA<vt.TileResponseData>(),
    );
    expect(await store.cacheBytes(), greaterThan(0));
    await store.trimCache(maxBytes: 0);
    expect(await store.cacheBytes(), 0);
  });
}
