import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/event_category.dart';
import '../db/app_database.dart';
import '../sync/change_recorder.dart';

class CategoryRepository {
  CategoryRepository(this._db, {DateTime Function()? clock, this.recorder})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final ChangeRecorder? recorder;

  Future<void> _changed(String id) async => recorder?.record('category', [id]);
  static const _uuid = Uuid();

  int _now() => _clock().toUtc().millisecondsSinceEpoch;

  Stream<List<EventCategory>> watchAll() {
    final query = _db.select(_db.categories)
      ..where((c) => c.deletedAt.isNull())
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  Future<EventCategory> create({
    required String name,
    required int color,
  }) async {
    final now = _now();
    final maxOrder = _db.categories.sortOrder.max();
    final last = await (_db.selectOnly(
      _db.categories,
    )..addColumns([maxOrder])).map((r) => r.read(maxOrder)).getSingle();
    final row = CategoriesCompanion.insert(
      id: _uuid.v4(),
      name: name,
      color: color,
      sortOrder: Value((last ?? -1) + 1),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.categories).insert(row);
    await _changed(row.id.value);
    return EventCategory(
      id: row.id.value,
      name: name,
      color: color,
      sortOrder: row.sortOrder.value,
    );
  }

  Future<void> update(EventCategory category) async {
    await (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(category.id))).write(
      CategoriesCompanion(
        name: Value(category.name),
        color: Value(category.color),
        sortOrder: Value(category.sortOrder),
        updatedAt: Value(_now()),
      ),
    );
  }

  /// Soft delete. Events keep their category id and fall back to the
  /// default color.
  Future<void> delete(String id) async {
    final now = _now();
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await _changed(id);
  }

  static EventCategory _toEntity(CategoryRow r) => EventCategory(
    id: r.id,
    name: r.name,
    color: r.color,
    sortOrder: r.sortOrder,
  );
}
