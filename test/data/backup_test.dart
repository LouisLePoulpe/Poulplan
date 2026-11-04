import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/data/backup/backup_service.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/repositories/birthday_repository.dart';
import 'package:poulplan/data/repositories/category_repository.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/data/repositories/saved_filter_repository.dart';
import 'package:poulplan/data/sync/change_recorder.dart';
import 'package:poulplan/data/sync/entity_codecs.dart';
import 'package:poulplan/domain/search/search_query.dart';
import 'package:poulplan/domain/sync/hlc.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, Map<String, Map<String, Object?>>>> dump(
    AppDatabase db,
  ) async => {
    for (final codec in codecs)
      codec.entity: {
        for (final id in await codec.allIds(db))
          id: (await codec.read(db, id))!..remove('createdAt'),
      },
  };

  Future<void> fill() async {
    final category = await CategoryRepository(source)
        .create(name: 'Sport', color: 0xFF00AA00);
    final events = EventRepository(source);
    await events.create(
      title: 'Piscine',
      categoryId: category.id,
      start: DateTime.utc(2026, 11, 3, 17),
      end: DateTime.utc(2026, 11, 3, 18),
      timeZone: 'Europe/Paris',
      rrule: 'FREQ=WEEKLY',
      reminders: [10, 60],
    );
    final gone = await events.create(
      title: 'Supprimé',
      start: DateTime.utc(2026, 11, 4, 9),
      end: DateTime.utc(2026, 11, 4, 10),
      timeZone: 'UTC',
    );
    await events.delete(gone.id);
    await BirthdayRepository(source)
        .create(name: 'Léa', month: 4, day: 12, birthYear: 1996);
    await SavedFilterRepository(source)
        .save('Sport', SearchQuery(text: 'piscine'));
  }

  test('a backup restored on an empty device gives the same data', () async {
    await fill();
    final bytes = await BackupService(source).create(device: 'pc');
    final result = await BackupService(target).restore(bytes);

    final expected = await dump(source);
    // Deleted records are not part of a backup.
    expected['event']!.removeWhere((_, f) => f['title'] == 'Supprimé');
    expect(await dump(target), expected);
    expect(
      result.records,
      expected.values.fold<int>(0, (n, records) => n + records.length),
    );
  });

  test('the archive carries a readable manifest', () async {
    await fill();
    final bytes = await BackupService(source).create(device: 'pc');
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifest = jsonDecode(
      utf8.decode(archive.findFile('poulplan-backup.json')!.content),
    ) as Map<String, dynamic>;
    expect(manifest['format'], 'poulplan-backup');
    expect(manifest['version'], 1);
    expect(manifest['device'], 'pc');
    final info = await BackupService.inspect(bytes);
    expect(info.events, 1);
    expect(info.birthdays, 1);
  });

  test('restoring merges: local records absent from the backup stay', () async {
    await fill();
    final bytes = await BackupService(source).create(device: 'pc');
    final local = await EventRepository(target).create(
      title: 'Local',
      start: DateTime.utc(2026, 12, 1, 9),
      end: DateTime.utc(2026, 12, 1, 10),
      timeZone: 'UTC',
    );
    await BackupService(target).restore(bytes);
    final titles = (await dump(
      target,
    ))['event']!.values.map((f) => f['title']).toSet();
    expect(titles, {'Piscine', local.title});
  });

  test('restored records are queued for the synchronization', () async {
    await fill();
    final bytes = await BackupService(source).create(device: 'pc');
    final recorder = ChangeRecorder(target, HlcClock('dev2'));
    await BackupService(target, recorder: recorder).restore(bytes);
    final dirty = await (target.select(
      target.syncMeta,
    )..where((m) => m.dirty.equals(true))).get();
    expect(dirty.map((m) => m.entity).toSet(), {
      'event',
      'category',
      'birthday',
      'saved_filter',
    });
  });

  test('a file that is not a backup is rejected', () async {
    expect(
      () => BackupService(target).restore(utf8.encode('pas une archive')),
      throwsA(isA<BackupFormatException>()),
    );
    final other = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile.string('autre.txt', 'x')),
    );
    expect(
      () => BackupService(target).restore(other),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('a backup from a newer version is rejected', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'poulplan-backup.json',
          jsonEncode({'format': 'poulplan-backup', 'version': 99}),
        ),
      );
    expect(
      () => BackupService(target).restore(ZipEncoder().encode(archive)),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
