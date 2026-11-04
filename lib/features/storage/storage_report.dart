import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../core/platform/file_exchange.dart';
import '../../data/db/connection.dart';
import '../../data/providers.dart';
import '../backup/backup_manager.dart';

/// Below this free space, Poulplan proposes to clean up.
const lowSpaceBytes = 500 * 1024 * 1024;

/// Space used by Poulplan on this device, and what can be freed.
@immutable
class StorageReport {
  const StorageReport({
    required this.databaseBytes,
    required this.attachmentBytes,
    required this.freeableAttachmentBytes,
    required this.backupBytes,
    required this.oldBackupBytes,
    this.freeBytes,
  });

  final int databaseBytes;
  final int attachmentBytes;

  /// Attachment copies that are in the cloud and not kept offline.
  final int freeableAttachmentBytes;
  final int backupBytes;

  /// Local backups other than the newest one.
  final int oldBackupBytes;

  /// Free space on the device, when known.
  final int? freeBytes;

  int get totalBytes => databaseBytes + attachmentBytes + backupBytes;

  int get reclaimableBytes => freeableAttachmentBytes + oldBackupBytes;

  bool get lowSpace => freeBytes != null && freeBytes! < lowSpaceBytes;

  bool get proposeCleanup => lowSpace && reclaimableBytes > 0;
}

final storageReportProvider = FutureProvider.autoDispose<StorageReport>((
  ref,
) async {
  final directory = ref.watch(appDirectoryProvider);
  final attachments = ref.watch(attachmentRepositoryProvider);
  final backups = await (await ref.read(backupManagerProvider).localStore())
      .list();
  var database = 0;
  for (final suffix in ['', '-wal', '-shm']) {
    final file = File(p.join(directory.path, '$databaseFileName$suffix'));
    if (file.existsSync()) database += await file.length();
  }
  return StorageReport(
    databaseBytes: database,
    attachmentBytes: await attachments.localBytes(),
    freeableAttachmentBytes: await attachments.freeableBytes(),
    backupBytes: backups.fold<int>(0, (sum, b) => sum + (b.size ?? 0)),
    oldBackupBytes: backups
        .skip(1)
        .fold<int>(0, (sum, b) => sum + (b.size ?? 0)),
    freeBytes: await FileExchange.freeBytes(directory.path),
  );
});

/// Keeps only the newest local backup; returns the bytes freed.
Future<int> deleteOldBackups(WidgetRef ref) async {
  final store = await ref.read(backupManagerProvider).localStore();
  final before = await store.totalSize();
  await store.prune(keep: 1);
  return before - await store.totalSize();
}
