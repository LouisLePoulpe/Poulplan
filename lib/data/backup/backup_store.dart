import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase/supabase.dart';

/// A stored backup (local file or cloud object).
class StoredBackup {
  const StoredBackup({required this.name, required this.date, this.size});

  final String name;
  final DateTime date;

  /// Bytes, when known.
  final int? size;
}

final _namePattern = RegExp(
  r'^poulplan-(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})\.zip$',
);

String _two(int n) => n.toString().padLeft(2, '0');

/// `poulplan-2026-11-04-0205.zip` for a local time: names sort by date.
String backupFileName(DateTime local) =>
    'poulplan-${local.year}-${_two(local.month)}-${_two(local.day)}-'
    '${_two(local.hour)}${_two(local.minute)}.zip';

DateTime? backupDate(String name) {
  final m = _namePattern.firstMatch(name);
  if (m == null) return null;
  final v = [for (var i = 1; i <= 5; i++) int.parse(m[i]!)];
  return DateTime(v[0], v[1], v[2], v[3], v[4]);
}

/// Backups to delete so that only the [keep] newest remain; files that are
/// not automatic backups are never touched.
List<String> backupsToPrune(Iterable<String> names, {required int keep}) {
  final backups = names.where((n) => backupDate(n) != null).toList()
    ..sort((a, b) => b.compareTo(a));
  return backups.length <= keep ? const [] : backups.sublist(keep);
}

/// Daily backups; a last backup « in the future » (clock changed) does not
/// count.
bool isBackupDue(DateTime? last, DateTime now) =>
    last == null ||
    last.isAfter(now) ||
    now.difference(last) >= const Duration(hours: 24);

/// Backups kept on this device.
class LocalBackupStore {
  LocalBackupStore(this.directory);

  final Directory directory;

  Future<List<StoredBackup>> list() async {
    if (!directory.existsSync()) return const [];
    final result = <StoredBackup>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final date = backupDate(name);
      if (date == null) continue;
      result.add(
        StoredBackup(name: name, date: date, size: await entity.length()),
      );
    }
    return result..sort((a, b) => b.name.compareTo(a.name));
  }

  Future<StoredBackup> write(List<int> bytes, DateTime local) async {
    await directory.create(recursive: true);
    final name = backupFileName(local);
    final file = File(p.join(directory.path, name));
    // Written next to it first: an interrupted backup never replaces a good one.
    final temp = File('${file.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
    return StoredBackup(name: name, date: local, size: bytes.length);
  }

  Future<Uint8List> read(String name) =>
      File(p.join(directory.path, p.basename(name))).readAsBytes();

  Future<void> delete(String name) async {
    final file = File(p.join(directory.path, p.basename(name)));
    if (file.existsSync()) await file.delete();
  }

  Future<void> prune({required int keep}) async {
    final names = (await list()).map((b) => b.name);
    for (final name in backupsToPrune(names, keep: keep)) {
      await delete(name);
    }
  }

  Future<int> totalSize() async =>
      (await list()).fold<int>(0, (sum, b) => sum + (b.size ?? 0));
}

/// Backups in the private cloud Storage: `<user id>/backups/<name>`.
class CloudBackupStore {
  CloudBackupStore(this._client);

  final SupabaseClient _client;

  static const bucket = 'poulplan-attachments';

  String get _folder => '${_client.auth.currentUser!.id}/backups';

  Future<List<StoredBackup>> list() async {
    final objects = await _client.storage.from(bucket).list(path: _folder);
    final result = <StoredBackup>[];
    for (final o in objects) {
      final date = backupDate(o.name);
      if (date == null) continue;
      final size = o.metadata?['size'];
      result.add(
        StoredBackup(name: o.name, date: date, size: size is int ? size : null),
      );
    }
    return result..sort((a, b) => b.name.compareTo(a.name));
  }

  Future<void> upload(String name, List<int> bytes) => _client.storage
      .from(bucket)
      .uploadBinary(
        '$_folder/$name',
        Uint8List.fromList(bytes),
        fileOptions: const FileOptions(
          contentType: 'application/zip',
          upsert: true,
        ),
      );

  Future<Uint8List> download(String name) =>
      _client.storage.from(bucket).download('$_folder/$name');

  Future<void> prune({required int keep}) async {
    final names = (await list()).map((b) => b.name);
    final old = backupsToPrune(names, keep: keep);
    if (old.isEmpty) return;
    await _client.storage.from(bucket).remove([
      for (final name in old) '$_folder/$name',
    ]);
  }
}
