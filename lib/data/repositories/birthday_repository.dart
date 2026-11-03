import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/birthday.dart';
import '../db/app_database.dart';
import '../sync/change_recorder.dart';

class BirthdayRepository {
  BirthdayRepository(this._db, {DateTime Function()? clock, this.recorder})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final ChangeRecorder? recorder;

  Future<void> _changed(String id) async => recorder?.record('birthday', [id]);
  static const _uuid = Uuid();

  int _now() => _clock().toUtc().millisecondsSinceEpoch;

  Stream<List<Birthday>> watchAll() {
    final query = _db.select(_db.birthdays)
      ..where((b) => b.deletedAt.isNull())
      ..orderBy([
        (b) => OrderingTerm.asc(b.month),
        (b) => OrderingTerm.asc(b.day),
        (b) => OrderingTerm.asc(b.name),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  Future<Birthday> create({
    required String name,
    required int month,
    required int day,
    int? birthYear,
  }) async {
    final now = _now();
    final row = BirthdaysCompanion.insert(
      id: _uuid.v4(),
      name: name,
      month: month,
      day: day,
      birthYear: Value(birthYear),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.birthdays).insert(row);
    await _changed(row.id.value);
    return _toEntity(
      await (_db.select(
        _db.birthdays,
      )..where((b) => b.id.equals(row.id.value))).getSingle(),
    );
  }

  Future<void> update(Birthday birthday) async {
    await (_db.update(
      _db.birthdays,
    )..where((b) => b.id.equals(birthday.id))).write(
      BirthdaysCompanion(
        name: Value(birthday.name),
        month: Value(birthday.month),
        day: Value(birthday.day),
        birthYear: Value(birthday.birthYear),
        updatedAt: Value(_now()),
      ),
    );
    await _changed(birthday.id);
  }

  Future<void> delete(String id) async {
    final now = _now();
    await (_db.update(_db.birthdays)..where((b) => b.id.equals(id))).write(
      BirthdaysCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await _changed(id);
  }

  static Birthday _toEntity(BirthdayRow r) => Birthday(
    id: r.id,
    name: r.name,
    month: r.month,
    day: r.day,
    birthYear: r.birthYear,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
  );
}
