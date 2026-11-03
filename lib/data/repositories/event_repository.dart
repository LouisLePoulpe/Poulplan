import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/calendar/day.dart';
import '../../domain/entities/calendar_event.dart';
import '../db/app_database.dart';

class EventRepository {
  EventRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  /// Truncated to milliseconds, the precision stored in the database.
  DateTime _nowUtc() => DateTime.fromMillisecondsSinceEpoch(
    _clock().millisecondsSinceEpoch,
    isUtc: true,
  );

  /// Live events that may touch the local days [first]…[last].
  ///
  /// The window is widened by a day on each side because local days are
  /// offset from UTC by up to ±14 h; callers filter precisely with
  /// `groupEventsByDay`.
  Stream<List<CalendarEvent>> watchBetween(Day first, Day last) {
    final from = first.addDays(-1).toUtcMidnight().millisecondsSinceEpoch;
    final to = last.addDays(2).toUtcMidnight().millisecondsSinceEpoch;
    final query = _db.select(_db.events)
      ..where(
        (e) =>
            e.deletedAt.isNull() &
            e.startUtc.isSmallerThanValue(to) &
            e.endUtc.isBiggerOrEqualValue(from),
      )
      ..orderBy([(e) => OrderingTerm.asc(e.startUtc)]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  Future<CalendarEvent?> findById(String id) async {
    final row = await (_db.select(
      _db.events,
    )..where((e) => e.id.equals(id) & e.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  /// Creates an event and returns it with its generated id and timestamps.
  Future<CalendarEvent> create({
    required String title,
    String description = '',
    String? categoryId,
    int? color,
    String? location,
    String? videoLink,
    bool busy = true,
    bool allDay = false,
    required DateTime start,
    required DateTime end,
    required String timeZone,
  }) async {
    final now = _nowUtc();
    final event = CalendarEvent(
      id: _uuid.v4(),
      title: title,
      description: description,
      categoryId: categoryId,
      color: color,
      location: location,
      videoLink: videoLink,
      busy: busy,
      allDay: allDay,
      start: start.toUtc(),
      end: end.toUtc(),
      timeZone: timeZone,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.events).insert(_toCompanion(event));
    return event;
  }

  Future<void> update(CalendarEvent event) async {
    final updated = event.copyWith(updatedAt: _nowUtc());
    await (_db.update(
      _db.events,
    )..where((e) => e.id.equals(event.id))).write(_toCompanion(updated));
  }

  /// Copy of [event] with a new id, same times.
  Future<CalendarEvent> duplicate(CalendarEvent event) => create(
    title: event.title,
    description: event.description,
    categoryId: event.categoryId,
    color: event.color,
    location: event.location,
    videoLink: event.videoLink,
    busy: event.busy,
    allDay: event.allDay,
    start: event.start,
    end: event.end,
    timeZone: event.timeZone,
  );

  /// Undoes [delete].
  Future<void> restore(String id) async {
    await (_db.update(_db.events)..where((e) => e.id.equals(id))).write(
      EventsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(_nowUtc().millisecondsSinceEpoch),
      ),
    );
  }

  /// Soft delete: keeps a tombstone for the sync.
  Future<void> delete(String id) async {
    final now = _nowUtc().millisecondsSinceEpoch;
    await (_db.update(_db.events)..where((e) => e.id.equals(id))).write(
      EventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  static CalendarEvent _toEntity(EventRow r) => CalendarEvent(
    id: r.id,
    title: r.title,
    description: r.description,
    categoryId: r.categoryId,
    color: r.color,
    location: r.location,
    videoLink: r.videoLink,
    busy: r.busy,
    allDay: r.allDay,
    start: _utc(r.startUtc),
    end: _utc(r.endUtc),
    timeZone: r.timeZone,
    createdAt: _utc(r.createdAt),
    updatedAt: _utc(r.updatedAt),
  );

  static EventsCompanion _toCompanion(CalendarEvent e) => EventsCompanion(
    id: Value(e.id),
    title: Value(e.title),
    description: Value(e.description),
    categoryId: Value(e.categoryId),
    color: Value(e.color),
    location: Value(e.location),
    videoLink: Value(e.videoLink),
    busy: Value(e.busy),
    allDay: Value(e.allDay),
    startUtc: Value(e.start.millisecondsSinceEpoch),
    endUtc: Value(e.end.millisecondsSinceEpoch),
    timeZone: Value(e.timeZone),
    createdAt: Value(e.createdAt.millisecondsSinceEpoch),
    updatedAt: Value(e.updatedAt.millisecondsSinceEpoch),
  );

  static DateTime _utc(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
