import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/data/backup/backup_store.dart';

void main() {
  test('backup file names sort by date', () {
    expect(
      backupFileName(DateTime(2026, 11, 4, 2, 5)),
      'poulplan-2026-11-04-0205.zip',
    );
    expect(
      backupDate('poulplan-2026-11-04-0205.zip'),
      DateTime(2026, 11, 4, 2, 5),
    );
    expect(backupDate('notes.zip'), isNull);
  });

  test('only the oldest backups beyond the limit are pruned', () {
    expect(
      backupsToPrune([
        'poulplan-2026-11-01-0900.zip',
        'poulplan-2026-11-03-0900.zip',
        'autre.zip',
        'poulplan-2026-11-02-0900.zip',
        'poulplan-2026-11-04-0900.zip',
      ], keep: 2),
      ['poulplan-2026-11-02-0900.zip', 'poulplan-2026-11-01-0900.zip'],
    );
    expect(backupsToPrune(['poulplan-2026-11-01-0900.zip'], keep: 2), isEmpty);
  });

  test('a backup is due a day after the last one', () {
    final now = DateTime.utc(2026, 11, 4, 12);
    expect(isBackupDue(null, now), isTrue);
    expect(isBackupDue(now.subtract(const Duration(hours: 23)), now), isFalse);
    expect(isBackupDue(now.subtract(const Duration(hours: 24)), now), isTrue);
    // A clock set back does not block the backups forever.
    expect(isBackupDue(now.add(const Duration(days: 2)), now), isTrue);
  });

  test('local store writes, lists newest first and prunes', () async {
    final dir = await Directory.systemTemp.createTemp('poulplan_backups');
    addTearDown(() => dir.delete(recursive: true));
    final store = LocalBackupStore(dir);
    for (final day in [1, 2, 3]) {
      await store.write([day], DateTime(2026, 11, day, 9));
    }
    await store.prune(keep: 2);
    final list = await store.list();
    expect(list.map((b) => b.name), [
      'poulplan-2026-11-03-0900.zip',
      'poulplan-2026-11-02-0900.zip',
    ]);
    expect(await store.read(list.first.name), [3]);
    expect(list.first.size, 1);
  });
}
