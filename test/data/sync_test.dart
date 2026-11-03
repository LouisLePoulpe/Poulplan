import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/repositories/category_repository.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/data/sync/change_recorder.dart';
import 'package:poulplan/data/sync/sync_engine.dart';
import 'package:poulplan/data/sync/sync_remote.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/entities/calendar_event.dart';
import 'package:poulplan/domain/sync/hlc.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// In-memory server with the semantics of `poulplan_push` (supabase/).
class FakeRemote implements SyncRemote {
  final _records = <(String, String), RemoteRecord>{};
  var _rev = 0;
  var offline = false;
  var pushCalls = 0;

  void _check() {
    if (offline) throw Exception('network unreachable');
  }

  @override
  Future<List<RemoteRecord>> pull(int afterRev, {int limit = 500}) async {
    _check();
    return (_records.values.where((r) => r.rev > afterRev).toList()
          ..sort((a, b) => a.rev.compareTo(b.rev)))
        .take(limit)
        .toList();
  }

  @override
  Future<List<PushResult>> push(List<PushItem> items) async {
    _check();
    pushCalls++;
    return [
      for (final item in items)
        () {
          final key = (item.entity, item.id);
          final current = _records[key];
          if (current != null && current.rev != item.baseRev) {
            return (
              entity: item.entity,
              id: item.id,
              rev: current.rev,
              conflict: true,
            );
          }
          final record = RemoteRecord(
            entity: item.entity,
            id: item.id,
            data: item.data,
            deleted: item.deleted,
            rev: ++_rev,
          );
          _records[key] = record;
          return (
            entity: item.entity,
            id: item.id,
            rev: record.rev,
            conflict: false,
          );
        }(),
    ];
  }

  @override
  Future<RemoteRecord?> fetch(String entity, String id) async {
    _check();
    return _records[(entity, id)];
  }
}

/// One installation of the app: its own database, clock and engine.
class Device {
  Device(this.name, this.remote, {AppDatabase? db})
    : db = db ?? AppDatabase(NativeDatabase.memory()) {
    _connect();
  }

  final String name;
  final FakeRemote remote;
  final AppDatabase db;
  var now = 1000000;
  late ChangeRecorder recorder;
  late EventRepository events;
  late CategoryRepository categories;
  late SyncEngine engine;

  void _connect() {
    recorder = ChangeRecorder(db, HlcClock(name, now: () => now));
    events = EventRepository(
      db,
      recorder: recorder,
      clock: () => DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
    );
    categories = CategoryRepository(db, recorder: recorder);
    engine = SyncEngine(db, remote, recorder);
  }

  /// Simulates an app restart on the same database.
  void restart() => _connect();

  Future<SyncReport> sync() {
    now += 1000;
    return engine.sync();
  }

  Future<List<CalendarEvent>> all() =>
      events.watchBetween(Day(2026, 1, 1), Day(2026, 12, 31)).first;

  Future<List<SyncConflictRow>> conflicts() =>
      db.select(db.syncConflicts).get();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late FakeRemote remote;
  late Device a;
  late Device b;

  setUpAll(tzdata.initializeTimeZones);

  setUp(() {
    remote = FakeRemote();
    a = Device('deviceA', remote);
    b = Device('deviceB', remote);
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  Future<CalendarEvent> meeting(Device d) => d.events.create(
    title: 'Réunion',
    location: 'Salle A',
    start: DateTime.utc(2026, 3, 10, 9),
    end: DateTime.utc(2026, 3, 10, 10),
    timeZone: 'UTC',
  );

  test(
    'an event created on A appears on B with the same id and fields',
    () async {
      final created = await meeting(a);
      await a.sync();
      final report = await b.sync();
      final onB = (await b.all()).single;
      expect(onB.id, created.id);
      expect(onB.title, 'Réunion');
      expect(onB.location, 'Salle A');
      expect(report.conflicts, 0);
    },
  );

  test('default categories seeded on both devices do not conflict or '
      'duplicate', () async {
    await a.sync();
    await b.sync();
    await a.sync();
    expect(await a.conflicts(), isEmpty);
    expect(await b.conflicts(), isEmpty);
    expect(await b.categories.watchAll().first, hasLength(4));
  });

  test(
    'offline edits of different fields on both devices are merged',
    () async {
      final created = await meeting(a);
      await a.sync();
      await b.sync();

      a.now += 10;
      await a.events.update(created.copyWith(title: 'Réunion projet'));
      b.now += 20;
      final onB = (await b.events.findById(created.id))!;
      await b.events.update(onB.copyWith(location: () => 'Salle B'));

      await a.sync();
      await b.sync(); // conflict on push → fetch, merge, push again
      await a.sync();

      for (final device in [a, b]) {
        final event = (await device.events.findById(created.id))!;
        expect(event.title, 'Réunion projet', reason: device.name);
        expect(event.location, 'Salle B', reason: device.name);
        expect(await device.conflicts(), isEmpty, reason: device.name);
      }
    },
  );

  test(
    'the same field changed on both devices is a conflict for the user',
    () async {
      final created = await meeting(a);
      await a.sync();
      await b.sync();

      await a.events.update(created.copyWith(title: 'Dentiste'));
      b.now += 5000; // B's change is more recent
      final onB = (await b.events.findById(created.id))!;
      await b.events.update(onB.copyWith(title: 'Orthodontiste'));

      await a.sync();
      await b.sync();
      await a.sync();

      final conflict = (await b.conflicts()).single;
      expect(conflict.field, 'title');
      expect(conflict.localValue, '"Orthodontiste"');
      expect(conflict.remoteValue, '"Dentiste"');
      // Both devices converge on the provisional (most recent) value.
      expect((await a.events.findById(created.id))!.title, 'Orthodontiste');
      expect((await b.events.findById(created.id))!.title, 'Orthodontiste');
    },
  );

  test('a deletion propagates', () async {
    final created = await meeting(a);
    await a.sync();
    await b.sync();
    await a.events.delete(created.id);
    await a.sync();
    await b.sync();
    expect(await b.all(), isEmpty);
    expect(await b.conflicts(), isEmpty);
  });

  test('deleted on A while edited on B: kept, and flagged', () async {
    final created = await meeting(a);
    await a.sync();
    await b.sync();
    await a.events.delete(created.id);
    final onB = (await b.events.findById(created.id))!;
    await b.events.update(onB.copyWith(title: 'Réunion (déplacée)'));

    await a.sync();
    await b.sync();
    await a.sync();

    expect((await b.conflicts()).single.field, '_deleted');
    for (final device in [a, b]) {
      expect(
        (await device.events.findById(created.id))?.title,
        'Réunion (déplacée)',
        reason: device.name,
      );
    }
  });

  test('changes made offline are queued, survive a restart and are sent '
      'when the network is back', () async {
    remote.offline = true;
    final created = await meeting(a);
    await expectLater(a.sync(), throwsException);
    expect(await a.engine.pendingCount(), greaterThan(0));

    a.restart();
    expect(await a.engine.pendingCount(), greaterThan(0));
    remote.offline = false;
    await a.sync();
    expect(await a.engine.pendingCount(), 0);

    await b.sync();
    expect((await b.all()).single.id, created.id);
  });

  test('the app keeps working locally while the cloud is down', () async {
    remote.offline = true;
    final created = await meeting(a);
    await a.events.update(created.copyWith(title: 'Hors ligne'));
    expect((await a.all()).single.title, 'Hors ligne');
  });

  test('a recurring series with an overridden occurrence syncs', () async {
    await a.events.create(
      title: 'Cours',
      start: DateTime.utc(2026, 1, 5, 18),
      end: DateTime.utc(2026, 1, 5, 19),
      timeZone: 'UTC',
      rrule: 'FREQ=WEEKLY;COUNT=4',
    );
    final second = (await a.all())[1];
    await a.events.saveOccurrence(
      second.copyWith(title: 'Cours (salle B)'),
      SeriesScope.thisOccurrence,
    );
    await a.sync();
    await b.sync();
    expect((await b.all()).map((e) => e.title), [
      'Cours',
      'Cours (salle B)',
      'Cours',
      'Cours',
    ]);
  });

  test(
    'syncing again re-reads the overlap without changing anything',
    () async {
      await meeting(a);
      await a.sync();
      await b.sync();
      final report = await b.sync();
      expect(report.pulled, 0);
      expect(report.pushed, 0);
    },
  );

  test('records are pushed in batches, one call per batch', () async {
    await a.db.batch((batch) {
      for (var i = 0; i < 250; i++) {
        batch.insert(
          a.db.events,
          EventsCompanion.insert(
            id: 'e$i',
            title: 'E$i',
            startUtc: 0,
            endUtc: 1,
            timeZone: 'UTC',
            createdAt: 0,
            updatedAt: 0,
            searchText: Value('e$i'),
          ),
        );
      }
    });
    await a.sync();
    // 250 events + 4 default categories, by 100.
    expect(remote.pushCalls, 3);
    await b.sync();
    expect(await b.db.select(b.db.events).get().then((r) => r.length), 250);
  });
}
