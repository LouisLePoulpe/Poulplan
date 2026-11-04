import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/data/attachments/attachment_transfer.dart';
import 'package:poulplan/data/backup/backup_service.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/repositories/attachment_repository.dart';
import 'package:poulplan/data/sync/change_recorder.dart';
import 'package:poulplan/domain/entities/attachment.dart';
import 'package:poulplan/domain/sync/hlc.dart';

/// In-memory Storage bucket.
class FakeAttachmentRemote implements AttachmentRemote {
  final files = <String, List<int>>{};
  var offline = false;

  void _check() {
    if (offline) throw const SocketException('offline');
  }

  @override
  Future<void> upload(String path, List<int> bytes, String mimeType) async {
    _check();
    files[path] = bytes;
  }

  @override
  Future<List<int>> download(String path) async {
    _check();
    final bytes = files[path];
    if (bytes == null) throw AttachmentNotFoundException(path);
    return bytes;
  }

  @override
  Future<void> remove(List<String> paths) async {
    _check();
    paths.forEach(files.remove);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory dir;
  late AttachmentRepository repository;
  late FakeAttachmentRemote remote;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('poulplan_attachments');
    repository = AttachmentRepository(db, directory: dir);
    remote = FakeAttachmentRemote();
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  AttachmentTransfer transfer([AttachmentRepository? repo]) =>
      AttachmentTransfer(repo ?? repository, remote, userId: 'u1');

  test('guessing types and cleaning names', () {
    expect(guessMimeType('Billet.PDF'), 'application/pdf');
    expect(guessMimeType('notes'), 'application/octet-stream');
    expect(safeFileName('../../etc/passwd'), 'passwd');
    expect(safeFileName('.cache'), 'cache');
    expect(safeFileName('  '), 'fichier');
  });

  test('an added file is stored on the device and listed', () async {
    final a = await repository.add('e1', 'billet.pdf', [1, 2, 3]);
    expect(a.mimeType, 'application/pdf');
    expect(a.size, 3);
    expect(a.stored, isTrue);
    expect(await repository.file(a).readAsBytes(), [1, 2, 3]);
    final listed = await repository.watchForEvent('e1').first;
    expect(listed.single.name, 'billet.pdf');
    expect(await repository.watchForEvent('e2').first, isEmpty);
  });

  test('changes are recorded for the synchronization', () async {
    final recorder = ChangeRecorder(db, HlcClock('dev1'));
    final repo = AttachmentRepository(db, directory: dir, recorder: recorder);
    final a = await repo.add('e1', 'photo.jpg', [9]);
    await repo.delete(a.id);
    final meta = await db.select(db.syncMeta).getSingle();
    expect(meta.entity, 'attachment');
    expect(meta.dirty, isTrue);
    expect(meta.fieldValues, contains('"_deleted":true'));
  });

  test('upload, then removal from the cloud when deleted', () async {
    final a = await repository.add('e1', 'billet.pdf', [1, 2, 3]);
    await transfer().run();
    expect(remote.files['u1/e1/${a.id}'], [1, 2, 3]);
    expect((await repository.find(a.id))!.uploaded, isTrue);

    await repository.delete(a.id);
    expect(repository.file(a).existsSync(), isFalse);
    await transfer().run();
    expect(remote.files, isEmpty);
  });

  test('another device downloads the files kept offline', () async {
    final a = await repository.add('e1', 'billet.pdf', [1, 2, 3]);
    await transfer().run();

    // The metadata reaches the other device through the synchronization.
    final otherDb = AppDatabase(NativeDatabase.memory());
    final otherDir = await Directory.systemTemp.createTemp('poulplan_other');
    addTearDown(() async {
      await otherDb.close();
      await otherDir.delete(recursive: true);
    });
    await otherDb
        .into(otherDb.attachments)
        .insert(
          (await (db.select(
            db.attachments,
          )..where((r) => r.id.equals(a.id))).getSingle()),
        );
    final other = AttachmentRepository(otherDb, directory: otherDir);
    expect((await other.find(a.id))!.stored, isFalse);

    await transfer(other).run();
    expect((await other.find(a.id))!.stored, isFalse, reason: 'not kept');

    await other.setKeepOffline(a.id, true);
    await transfer(other).run();
    final local = (await other.find(a.id))!;
    expect(local.stored, isTrue);
    expect(await other.file(local).readAsBytes(), [1, 2, 3]);

    // Opening a file that is not kept downloads it on demand.
    await other.forgetLocalCopy(a.id);
    await other.setKeepOffline(a.id, false);
    expect((await other.find(a.id))!.stored, isFalse);
    final opened = await transfer(other).fetch((await other.find(a.id))!);
    expect(await opened.readAsBytes(), [1, 2, 3]);
  });

  test('offline: nothing is lost, the transfer is retried', () async {
    final a = await repository.add('e1', 'billet.pdf', [1]);
    remote.offline = true;
    await transfer().run();
    expect((await repository.find(a.id))!.uploaded, isFalse);
    remote.offline = false;
    await transfer().run();
    expect((await repository.find(a.id))!.uploaded, isTrue);
  });

  test('a local copy is only freed when it is in the cloud', () async {
    final a = await repository.add('e1', 'billet.pdf', [1]);
    expect(await repository.freeableBytes(), 0);
    await transfer().run();
    expect(await repository.freeableBytes(), 1);
    await repository.setKeepOffline(a.id, true);
    expect(await repository.freeableBytes(), 0);
    await repository.setKeepOffline(a.id, false);
    expect(await repository.freeLocalCopies(), 1);
    expect((await repository.find(a.id))!.stored, isFalse);
    expect(repository.file(a).existsSync(), isFalse);
  });

  test('backups carry the files that are on the device', () async {
    final a = await repository.add('e1', 'billet.pdf', [4, 5]);
    final bytes = await BackupService(
      db,
      attachments: repository,
    ).create(device: 'pc');

    final otherDb = AppDatabase(NativeDatabase.memory());
    final otherDir = await Directory.systemTemp.createTemp('poulplan_restore');
    addTearDown(() async {
      await otherDb.close();
      await otherDir.delete(recursive: true);
    });
    final other = AttachmentRepository(otherDb, directory: otherDir);
    await BackupService(otherDb, attachments: other).restore(bytes);
    final restored = (await other.find(a.id))!;
    expect(restored.stored, isTrue);
    expect(restored.uploaded, isFalse);
    expect(await other.file(restored).readAsBytes(), [4, 5]);
  });
}
