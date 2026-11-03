import 'package:drift/drift.dart';

import '../../domain/entities/event_category.dart';
import '../db/app_database.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<EventCategory>> watchAll() {
    final query = _db.select(_db.categories)
      ..where((c) => c.deletedAt.isNull())
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => EventCategory(
              id: r.id,
              name: r.name,
              color: r.color,
              sortOrder: r.sortOrder,
            ),
          )
          .toList(),
    );
  }
}
