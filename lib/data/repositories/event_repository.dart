import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../domain/calendar/day.dart';
import '../../domain/calendar/event_timing.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/holidays/french_holidays.dart';
import '../../domain/recurrence/expansion.dart';
import '../../domain/recurrence/recurrence_rule.dart';
import '../../domain/recurrence/series_edit.dart';
import '../../domain/search/search_query.dart';
import '../db/app_database.dart';
import '../sync/change_recorder.dart';

/// Which occurrences of a series an edit or a deletion applies to.
enum SeriesScope { thisOccurrence, thisAndFollowing, all }

class EventRepository {
  EventRepository(this._db, {DateTime Function()? clock, this.recorder})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final ChangeRecorder? recorder;

  Future<void> _changed(Iterable<String> ids) async =>
      recorder?.record('event', ids);

  /// Ids of [id] and of the overrides of the series [id].
  Future<List<String>> _withOverrides(String id) =>
      (_db.selectOnly(_events)
            ..addColumns([_events.id])
            ..where(_events.id.equals(id) | _events.seriesId.equals(id)))
          .map((r) => r.read(_events.id)!)
          .get();
  static const _uuid = Uuid();

  /// Truncated to milliseconds, the precision stored in the database.
  DateTime _nowUtc() => DateTime.fromMillisecondsSinceEpoch(
    _clock().millisecondsSinceEpoch,
    isUtc: true,
  );

  $EventsTable get _events => _db.events;

  /// Stored rows needed to display the local days [first]…[last]: plain
  /// events and overrides in range, series masters that may have occurrences
  /// in range, and all the overrides of those masters.
  ///
  /// The window is widened by a day on each side because local days are
  /// offset from UTC by up to ±14 h; use [expandEvents] then
  /// `groupEventsByDay` to get what to display.
  Stream<List<CalendarEvent>> watchRowsBetween(Day first, Day last) {
    final from = first.addDays(-1).toUtcMidnight().millisecondsSinceEpoch;
    final to = last.addDays(2).toUtcMidnight().millisecondsSinceEpoch;

    Expression<bool> activeMaster($EventsTable e) =>
        e.rrule.isNotNull() &
        e.seriesId.isNull() &
        e.deletedAt.isNull() &
        e.startUtc.isSmallerThanValue(to) &
        (e.recurrenceEndUtc.isNull() |
            e.recurrenceEndUtc.isBiggerOrEqualValue(from));

    final masters = _db.selectOnly(_events)
      ..addColumns([_events.id])
      ..where(activeMaster(_events));

    final query = _db.select(_events)
      ..where(
        (e) =>
            e.deletedAt.isNull() &
            ((e.startUtc.isSmallerThanValue(to) &
                    e.endUtc.isBiggerOrEqualValue(from)) |
                activeMaster(e) |
                e.seriesId.isInQuery(masters)),
      )
      ..orderBy([(e) => OrderingTerm.asc(e.startUtc)]);
    return query.watch().map((rows) => rows.map(rowToEvent).toList());
  }

  /// Events to display between [first] and [last] (recurrences expanded).
  Stream<List<CalendarEvent>> watchBetween(
    Day first,
    Day last, {
    tz.Location? display,
    HolidayCalendar? holidays,
  }) => watchRowsBetween(first, last).map(
    (rows) => expandEvents(
      rows,
      from: first,
      to: last,
      display: display ?? tz.UTC,
      holidays: holidays ?? HolidayCalendar(),
    ),
  );

  Future<CalendarEvent?> findById(String id) async {
    final row = await (_db.select(
      _events,
    )..where((e) => e.id.equals(id) & e.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : rowToEvent(row);
  }

  /// Resolves an id shown in the views: a stored event, or a generated
  /// occurrence (`<series>@<ms>`) rebuilt from its master.
  Future<CalendarEvent?> findDisplayed(String id) async {
    final occurrence = parseOccurrenceId(id);
    if (occurrence == null) return findById(id);
    final master = await findById(occurrence.seriesId);
    if (master == null) return null;
    final override =
        await (_db.select(_events)..where(
              (e) =>
                  e.seriesId.equals(master.id) &
                  e.originalStartUtc.equals(
                    occurrence.originalStart.millisecondsSinceEpoch,
                  ) &
                  e.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (override != null) return rowToEvent(override);
    return master.copyWith(
      id: id,
      start: occurrence.originalStart,
      end: occurrence.originalStart.add(master.duration),
      seriesId: () => master.id,
      originalStart: () => occurrence.originalStart,
    );
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
    String? rrule,
    HolidayRule holidayRule = HolidayRule.none,
    String? seriesId,
    DateTime? originalStart,
    bool cancelled = false,
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
      rrule: rrule,
      holidayRule: holidayRule,
      seriesId: seriesId,
      originalStart: originalStart?.toUtc(),
      cancelled: cancelled,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_events).insert(eventToCompanion(event));
    await _changed([event.id]);
    return event;
  }

  /// Saves a stored event (plain event, master or override).
  Future<void> update(CalendarEvent event) async {
    assert(!event.isOccurrence, 'Use saveOccurrence for generated ids');
    final updated = event.copyWith(updatedAt: _nowUtc());
    await (_db.update(
      _events,
    )..where((e) => e.id.equals(event.id))).write(eventToCompanion(updated));
    await _changed([event.id]);
  }

  /// Copy of [event] with a new id, same times (a single, non-recurring
  /// event when [event] is an occurrence).
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
    rrule: event.seriesId == null ? event.rrule : null,
    holidayRule: event.holidayRule,
  );

  /// Undoes [delete].
  Future<void> restore(String id) async {
    final ids = await _withOverrides(id);
    await (_db.update(
      _events,
    )..where((e) => e.id.equals(id) | e.seriesId.equals(id))).write(
      EventsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(_nowUtc().millisecondsSinceEpoch),
      ),
    );
    await _changed(ids);
  }

  /// Soft delete: keeps a tombstone for the sync. Deleting a master also
  /// deletes its overrides.
  Future<void> delete(String id) async {
    final ids = await _withOverrides(id);
    final now = _nowUtc().millisecondsSinceEpoch;
    await (_db.update(_events)
          ..where((e) => e.id.equals(id) | e.seriesId.equals(id)))
        .write(EventsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    await _changed(ids);
  }

  /// Saves [edited], an occurrence of a series (generated or overridden),
  /// for the given [scope].
  Future<void> saveOccurrence(CalendarEvent edited, SeriesScope scope) async {
    final master = (await findById(edited.seriesId!))!;
    final originalStart = edited.originalStart!;
    switch (scope) {
      case SeriesScope.thisOccurrence:
        await _upsertOverride(master, edited);
      case SeriesScope.all:
        await _updateMaster(master, edited, originalStart);
      case SeriesScope.thisAndFollowing:
        await _db.transaction(() async {
          final remaining = await _cutSeries(master, originalStart);
          if (remaining == null) {
            await _updateMaster(master, edited, originalStart);
            return;
          }
          await create(
            title: edited.title,
            description: edited.description,
            categoryId: edited.categoryId,
            color: edited.color,
            location: edited.location,
            videoLink: edited.videoLink,
            busy: edited.busy,
            allDay: edited.allDay,
            start: edited.start,
            end: edited.end,
            timeZone: edited.timeZone,
            // Keep a rule changed in the form, else the remaining part.
            rrule: edited.rrule == master.rrule ? remaining : edited.rrule,
            holidayRule: edited.holidayRule,
          );
        });
    }
  }

  /// Deletes [occurrence] of a series for the given [scope]. Returns the id
  /// to pass to [restore] to undo it, when undo is possible.
  Future<String?> deleteOccurrence(
    CalendarEvent occurrence,
    SeriesScope scope,
  ) async {
    final master = await findById(occurrence.seriesId!);
    if (master == null) return null;
    switch (scope) {
      case SeriesScope.thisOccurrence:
        final id = await _upsertOverride(master, occurrence, cancelled: true);
        // Undo = un-cancel: handled by restoring the original values.
        return id;
      case SeriesScope.all:
        await delete(master.id);
        return master.id;
      case SeriesScope.thisAndFollowing:
        final remaining = await _cutSeries(master, occurrence.originalStart!);
        if (remaining == null) {
          await delete(master.id);
          return master.id;
        }
        return null;
    }
  }

  /// Un-cancels an occurrence cancelled by [deleteOccurrence].
  Future<void> uncancel(String overrideId) async {
    await (_db.update(_events)..where((e) => e.id.equals(overrideId))).write(
      EventsCompanion(
        cancelled: const Value(false),
        updatedAt: Value(_nowUtc().millisecondsSinceEpoch),
      ),
    );
    await _changed([overrideId]);
  }

  /// Ends [master] before [originalStart] and removes the overrides from
  /// there. Returns the rule of the remaining part, or null when the cut is
  /// at the very first occurrence (nothing would be left before it).
  Future<String?> _cutSeries(
    CalendarEvent master,
    DateTime originalStart,
  ) async {
    final rule = RecurrenceRule.parse(master.rrule!);
    final zone = master.allDay
        ? tz.UTC
        : locationOrFallback(master.timeZone, tz.UTC);
    final startDay = Day.fromDateTime(tz.TZDateTime.from(master.start, zone));
    final splitDay = Day.fromDateTime(tz.TZDateTime.from(originalStart, zone));
    final halves = splitRule(rule, startDay, splitDay);
    if (halves.beforeIsEmpty) return null;
    await update(master.copyWith(rrule: () => halves.before.toString()));
    final now = _nowUtc().millisecondsSinceEpoch;
    Expression<bool> later($EventsTable e) =>
        e.seriesId.equals(master.id) &
        e.originalStartUtc.isBiggerOrEqualValue(
          originalStart.millisecondsSinceEpoch,
        );
    final ids =
        await (_db.selectOnly(_events)
              ..addColumns([_events.id])
              ..where(later(_events)))
            .map((r) => r.read(_events.id)!)
            .get();
    await (_db.update(_events)..where(later)).write(
      EventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await _changed(ids);
    return halves.after.toString();
  }

  Future<void> _updateMaster(
    CalendarEvent master,
    CalendarEvent edited,
    DateTime originalStart,
  ) {
    // Moving one occurrence by Δ moves the whole series by Δ.
    final delta = edited.start.difference(originalStart);
    final start = master.start.add(delta);
    return update(
      master.copyWith(
        title: edited.title,
        description: edited.description,
        categoryId: () => edited.categoryId,
        color: () => edited.color,
        location: () => edited.location,
        videoLink: () => edited.videoLink,
        busy: edited.busy,
        allDay: edited.allDay,
        start: start,
        end: start.add(edited.duration),
        timeZone: edited.timeZone,
        rrule: () => edited.rrule ?? master.rrule,
        holidayRule: edited.holidayRule,
      ),
    );
  }

  Future<String> _upsertOverride(
    CalendarEvent master,
    CalendarEvent occurrence, {
    bool cancelled = false,
  }) async {
    final existing =
        await (_db.select(_events)..where(
              (e) =>
                  e.seriesId.equals(master.id) &
                  e.originalStartUtc.equals(
                    occurrence.originalStart!.millisecondsSinceEpoch,
                  ),
            ))
            .getSingleOrNull();
    if (existing != null) {
      final values = occurrence.copyWith(
        id: existing.id,
        rrule: () => null,
        seriesId: () => master.id,
        cancelled: cancelled,
        updatedAt: _nowUtc(),
      );
      await (_db.update(_events)..where((e) => e.id.equals(existing.id))).write(
        eventToCompanion(values).copyWith(
          createdAt: Value(existing.createdAt),
          deletedAt: const Value(null),
        ),
      );
      await _changed([existing.id]);
      return existing.id;
    }
    final created = await create(
      title: occurrence.title,
      description: occurrence.description,
      categoryId: occurrence.categoryId,
      color: occurrence.color,
      location: occurrence.location,
      videoLink: occurrence.videoLink,
      busy: occurrence.busy,
      allDay: occurrence.allDay,
      start: occurrence.start,
      end: occurrence.end,
      timeZone: occurrence.timeZone,
      seriesId: master.id,
      originalStart: occurrence.originalStart,
      cancelled: cancelled,
    );
    return created.id;
  }

  /// Stored events matching [query] (series appear once, as their master),
  /// most recent first.
  Future<List<CalendarEvent>> search(SearchQuery query, {int limit = 200}) {
    final select = _db.select(_events)
      ..where((e) {
        Expression<bool> condition =
            e.deletedAt.isNull() & e.cancelled.equals(false);
        for (final token in query.tokens) {
          condition = condition & e.searchText.like('%${_escape(token)}%');
        }
        if (query.categoryIds.isNotEmpty) {
          condition = condition & e.categoryId.isIn(query.categoryIds);
        }
        if (query.from != null) {
          final from = query.from!.toUtcMidnight().millisecondsSinceEpoch;
          condition =
              condition &
              (e.endUtc.isBiggerOrEqualValue(from) |
                  (e.rrule.isNotNull() &
                      (e.recurrenceEndUtc.isNull() |
                          e.recurrenceEndUtc.isBiggerOrEqualValue(from))));
        }
        if (query.to != null) {
          final to = query.to!
              .addDays(1)
              .toUtcMidnight()
              .millisecondsSinceEpoch;
          condition = condition & e.startUtc.isSmallerThanValue(to);
        }
        return condition;
      })
      ..orderBy([(e) => OrderingTerm.desc(e.startUtc)])
      ..limit(limit);
    return select.get().then((rows) => rows.map(rowToEvent).toList());
  }

  static String _escape(String token) =>
      token.replaceAll('%', '').replaceAll('_', '');

  static CalendarEvent rowToEvent(EventRow r) => CalendarEvent(
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
    rrule: r.rrule,
    holidayRule:
        HolidayRule.values.asNameMap()[r.holidayRule] ?? HolidayRule.none,
    seriesId: r.seriesId,
    originalStart: r.originalStartUtc == null
        ? null
        : _utc(r.originalStartUtc!),
    cancelled: r.cancelled,
    createdAt: _utc(r.createdAt),
    updatedAt: _utc(r.updatedAt),
  );

  static EventsCompanion eventToCompanion(CalendarEvent e) => EventsCompanion(
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
    rrule: Value(e.rrule),
    holidayRule: Value(e.holidayRule.name),
    seriesId: Value(e.seriesId),
    originalStartUtc: Value(e.originalStart?.millisecondsSinceEpoch),
    cancelled: Value(e.cancelled),
    recurrenceEndUtc: Value(_recurrenceEnd(e)),
    searchText: Value(searchTextFor(e.title, e.description, e.location)),
    createdAt: Value(e.createdAt.millisecondsSinceEpoch),
    updatedAt: Value(e.updatedAt.millisecondsSinceEpoch),
  );

  /// Upper bound of a bounded series, used to skip finished series quickly.
  static int? _recurrenceEnd(CalendarEvent e) {
    if (e.rrule == null) return null;
    try {
      final rule = RecurrenceRule.parse(e.rrule!);
      final zone = e.allDay ? tz.UTC : locationOrFallback(e.timeZone, tz.UTC);
      final last = rule.lastDay(
        Day.fromDateTime(tz.TZDateTime.from(e.start, zone)),
      );
      if (last == null) return null;
      return last
          .addDays(e.duration.inDays + 2)
          .toUtcMidnight()
          .millisecondsSinceEpoch;
    } on FormatException {
      return null;
    }
  }

  static DateTime _utc(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
