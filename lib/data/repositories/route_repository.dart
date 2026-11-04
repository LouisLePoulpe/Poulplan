import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/geo/geo.dart';
import '../../domain/geo/polyline.dart';
import '../../domain/geo/routing.dart';
import '../../domain/geo/stored_route.dart';
import '../db/app_database.dart';
import '../sync/change_recorder.dart';

/// Remembered routes, one per event (the last computed one).
class RouteRepository {
  RouteRepository(this._db, {this.recorder, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final ChangeRecorder? recorder;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  int _now() => _clock().toUtc().millisecondsSinceEpoch;

  static StoredRoute _toEntity(RouteRow r) => StoredRoute(
    id: r.id,
    eventId: r.eventId,
    mode: TravelMode.values.asNameMap()[r.mode] ?? TravelMode.car,
    originLabel: r.originLabel,
    origin: GeoPoint(r.originLatitude, r.originLongitude),
    destination: GeoPoint(r.destinationLatitude, r.destinationLongitude),
    result: RouteResult(
      distanceMeters: r.distanceMeters,
      durationSeconds: r.durationSeconds,
      points: decodePolyline(r.geometry),
    ),
    engine: r.engine,
    computedAt: DateTime.fromMillisecondsSinceEpoch(r.computedAt, isUtc: true),
  );

  SimpleSelectStatement<$RoutesTable, RouteRow> _forEvent(String eventId) =>
      _db.select(_db.routes)
        ..where((r) => r.eventId.equals(eventId) & r.deletedAt.isNull())
        ..orderBy([(r) => OrderingTerm.desc(r.computedAt)]);

  Stream<StoredRoute?> watchForEvent(String eventId) =>
      (_forEvent(eventId)..limit(1)).watch().map(
        (rows) => rows.isEmpty ? null : _toEntity(rows.first),
      );

  Future<StoredRoute?> findForEvent(String eventId) async {
    final rows = await (_forEvent(eventId)..limit(1)).get();
    return rows.isEmpty ? null : _toEntity(rows.first);
  }

  /// Remembers [result] as the route of [eventId], replacing the previous.
  Future<StoredRoute> save({
    required String eventId,
    required TravelMode mode,
    required Place origin,
    required GeoPoint destination,
    required RouteResult result,
    required String engine,
  }) async {
    final now = _now();
    final previous = await _forEvent(eventId).get();
    final id = _uuid.v4();
    await _db.transaction(() async {
      for (final old in previous) {
        await (_db.update(_db.routes)..where((r) => r.id.equals(old.id))).write(
          RoutesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
      }
      await _db
          .into(_db.routes)
          .insert(
            RoutesCompanion.insert(
              id: id,
              eventId: eventId,
              mode: mode.name,
              originLabel: origin.label,
              originLatitude: origin.point.latitude,
              originLongitude: origin.point.longitude,
              destinationLatitude: destination.latitude,
              destinationLongitude: destination.longitude,
              distanceMeters: result.distanceMeters,
              durationSeconds: result.durationSeconds,
              geometry: encodePolyline(result.points),
              engine: engine,
              computedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    await recorder?.record('route', [id, ...previous.map((r) => r.id)]);
    return (await findForEvent(eventId))!;
  }

  Future<void> deleteForEvent(String eventId) async {
    final now = _now();
    final rows = await _forEvent(eventId).get();
    for (final r in rows) {
      await (_db.update(_db.routes)..where((x) => x.id.equals(r.id))).write(
        RoutesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    }
    await recorder?.record('route', rows.map((r) => r.id));
  }
}
