import 'dart:convert';

import 'package:archive/archive.dart';

import '../db/app_database.dart';
import '../sync/change_recorder.dart';
import '../sync/entity_codecs.dart';
import '../../domain/sync/sync_record.dart';

/// The file is not a Poulplan backup, or comes from a newer version.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Summary of a backup, shown before restoring it.
class BackupInfo {
  const BackupInfo({
    required this.createdAt,
    required this.device,
    required this.counts,
  });

  final DateTime createdAt;
  final String device;

  /// Number of records per entity (`event`, `birthday`, …).
  final Map<String, int> counts;

  int get events => counts['event'] ?? 0;
  int get birthdays => counts['birthday'] ?? 0;
}

class RestoreResult {
  const RestoreResult({required this.records});

  final int records;
}

/// Backups: a zip with `poulplan-backup.json`, the records exactly as they
/// are synchronized (see `entity_codecs.dart`).
///
/// Restoring **merges**: records of the backup replace the local ones with
/// the same id, nothing else is deleted. Restored records are recorded as
/// local changes, so that they reach the cloud and the other devices.
class BackupService {
  BackupService(this._db, {this.recorder});

  final AppDatabase _db;
  final ChangeRecorder? recorder;

  static const format = 'poulplan-backup';
  static const version = 1;
  static const manifestName = 'poulplan-backup.json';

  /// Categories first: events reference them.
  static const _restoreOrder = [
    'category',
    'event',
    'birthday',
    'saved_filter',
  ];

  Future<List<int>> create({required String device, DateTime? now}) async {
    final records = <String, Map<String, Object?>>{};
    for (final codec in codecs) {
      final entityRecords = <String, Object?>{};
      for (final id in await codec.allIds(_db)) {
        final fields = await codec.read(_db, id);
        if (fields == null || fields[deletedField] == true) continue;
        entityRecords[id] = fields;
      }
      records[codec.entity] = entityRecords;
    }
    final manifest = {
      'format': format,
      'version': version,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'device': device,
      'records': records,
    };
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(manifestName, utf8.encode(jsonEncode(manifest))),
      );
    return ZipEncoder().encode(archive);
  }

  static Map<String, dynamic> _manifest(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupFormatException('not a zip archive');
    }
    final file = archive.findFile(manifestName);
    if (file == null) throw const BackupFormatException('no manifest');
    final Object? manifest;
    try {
      manifest = jsonDecode(utf8.decode(file.content));
    } catch (_) {
      throw const BackupFormatException('unreadable manifest');
    }
    if (manifest is! Map<String, dynamic> || manifest['format'] != format) {
      throw const BackupFormatException('not a Poulplan backup');
    }
    final v = manifest['version'];
    if (v is! int || v > version) {
      throw BackupFormatException('unsupported version $v');
    }
    return manifest;
  }

  static Map<String, Map<String, dynamic>> _records(
    Map<String, dynamic> manifest,
  ) => {
    for (final MapEntry(:key, :value)
        in (manifest['records'] as Map<String, dynamic>? ?? const {}).entries)
      key: value as Map<String, dynamic>,
  };

  static Future<BackupInfo> inspect(List<int> bytes) async {
    final manifest = _manifest(bytes);
    return BackupInfo(
      createdAt:
          DateTime.tryParse(manifest['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      device: manifest['device'] as String? ?? '',
      counts: {
        for (final MapEntry(:key, :value) in _records(manifest).entries)
          key: value.length,
      },
    );
  }

  Future<RestoreResult> restore(List<int> bytes) async {
    final records = _records(_manifest(bytes));
    final known = {for (final c in codecs) c.entity};
    final entities = [
      ..._restoreOrder,
      ...known.where((e) => !_restoreOrder.contains(e)),
    ].where(records.containsKey);
    var count = 0;
    for (final entity in entities) {
      final codec = codecFor(entity);
      final entityRecords = records[entity]!;
      await _db.transaction(() async {
        for (final MapEntry(:key, :value) in entityRecords.entries) {
          await codec.write(_db, key, Map<String, Object?>.from(value as Map));
        }
      });
      await recorder?.record(entity, entityRecords.keys);
      count += entityRecords.length;
    }
    return RestoreResult(records: count);
  }
}
