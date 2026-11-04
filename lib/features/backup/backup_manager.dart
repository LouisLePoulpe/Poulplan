import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/backup/backup_service.dart';
import '../../data/backup/backup_store.dart';
import '../../data/providers.dart';
import '../../data/repositories/event_repository.dart';
import '../../domain/exchange/ics_export.dart' as ics;
import '../sync/providers/sync_controller.dart';

final backupManagerProvider = Provider<BackupManager>((ref) {
  final manager = BackupManager(ref);
  ref.onDispose(manager.dispose);
  return manager;
});

/// Automatic and manual backups, restore and exports.
class BackupManager {
  BackupManager(this._ref);

  final Ref _ref;
  Timer? _timer;

  static const keepLocal = 7;
  static const keepCloud = 5;
  static const _lastLocalKey = 'backup_last_local';
  static const _lastCloudKey = 'backup_last_cloud';

  /// Checks a little after the start, then every hour.
  void start() {
    _timer = Timer(const Duration(seconds: 30), () {
      unawaited(runIfDue());
      _timer = Timer.periodic(
        const Duration(hours: 1),
        (_) => unawaited(runIfDue()),
      );
    });
  }

  void dispose() => _timer?.cancel();

  Future<LocalBackupStore> localStore() async => LocalBackupStore(
    Directory(p.join(_ref.read(appDirectoryProvider).path, 'backups')),
  );

  /// The cloud store when signed in.
  CloudBackupStore? cloudStore() {
    final session = _ref.read(cloudSessionProvider);
    return session != null && session.isSignedIn
        ? CloudBackupStore(session.client)
        : null;
  }

  BackupService _service() => BackupService(
    _ref.read(databaseProvider),
    recorder: _ref.read(changeRecorderProvider),
    attachments: _ref.read(attachmentRepositoryProvider),
  );

  /// Shown when restoring (« Linux », « Android »).
  static String get deviceName {
    final os = Platform.operatingSystem;
    return os[0].toUpperCase() + os.substring(1);
  }

  Future<List<int>> createBytes() => _service().create(device: deviceName);

  Future<StoredBackup> backupLocally() async {
    final store = await localStore();
    final now = DateTime.now();
    final backup = await store.write(await createBytes(), now);
    await store.prune(keep: keepLocal);
    await _setLast(_lastLocalKey, now);
    return backup;
  }

  Future<StoredBackup> backupToCloud() async {
    final store = cloudStore();
    if (store == null) throw StateError('not signed in');
    final now = DateTime.now();
    final name = backupFileName(now);
    final bytes = await createBytes();
    await store.upload(name, bytes);
    await store.prune(keep: keepCloud);
    await _setLast(_lastCloudKey, now);
    return StoredBackup(name: name, date: now, size: bytes.length);
  }

  /// The daily automatic backups (local, then cloud when signed in). Errors
  /// are only logged: the next check retries.
  Future<void> runIfDue() async {
    final settings = await _ref.read(settingsRepositoryProvider).watch().first;
    if (!settings.autoBackup) return;
    final now = DateTime.now();
    try {
      if (isBackupDue(await _last(_lastLocalKey), now)) await backupLocally();
    } catch (e) {
      debugPrint('Local backup failed: $e');
    }
    try {
      if (settings.cloudBackup &&
          cloudStore() != null &&
          isBackupDue(await _last(_lastCloudKey), now)) {
        await backupToCloud();
      }
    } catch (e) {
      debugPrint('Cloud backup failed: $e');
    }
  }

  Future<DateTime?> lastLocal() => _last(_lastLocalKey);

  Future<DateTime?> lastCloud() => _last(_lastCloudKey);

  Future<DateTime?> _last(String key) async {
    final raw = await _ref.read(settingsRepositoryProvider).getValue(key);
    final ms = int.tryParse(raw ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _setLast(String key, DateTime when) => _ref
      .read(settingsRepositoryProvider)
      .setValue(key, '${when.millisecondsSinceEpoch}');

  Future<BackupInfo> inspect(List<int> bytes) => BackupService.inspect(bytes);

  /// Merges the backup into the local data (see [BackupService.restore]).
  Future<RestoreResult> restore(List<int> bytes) => _service().restore(bytes);

  /// All the events as an iCalendar file.
  Future<String> exportIcs() async {
    final db = _ref.read(databaseProvider);
    final rows = await (db.select(
      db.events,
    )..where((e) => e.deletedAt.isNull())).get();
    final categories = await (db.select(
      db.categories,
    )..where((c) => c.deletedAt.isNull())).get();
    return ics.exportIcs(
      rows.map(EventRepository.rowToEvent).toList(),
      categoryNames: {for (final c in categories) c.id: c.name},
      now: DateTime.now(),
    );
  }
}
