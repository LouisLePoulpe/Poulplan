import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/search/search_query.dart';
import '../db/app_database.dart';

typedef SavedFilter = ({String id, String name, SearchQuery query});

class SavedFilterRepository {
  SavedFilterRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  Stream<List<SavedFilter>> watchAll() {
    final query = _db.select(_db.savedFilters)
      ..where((f) => f.deletedAt.isNull())
      ..orderBy([(f) => OrderingTerm.asc(f.name)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          (
            id: r.id,
            name: r.name,
            query: SearchQuery.fromJson(
              jsonDecode(r.query) as Map<String, dynamic>,
            ),
          ),
      ],
    );
  }

  Future<void> save(String name, SearchQuery query) async {
    final now = _now();
    await _db
        .into(_db.savedFilters)
        .insert(
          SavedFiltersCompanion.insert(
            id: _uuid.v4(),
            name: name,
            query: jsonEncode(query.toJson()),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> delete(String id) async {
    final now = _now();
    await (_db.update(_db.savedFilters)..where((f) => f.id.equals(id))).write(
      SavedFiltersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
