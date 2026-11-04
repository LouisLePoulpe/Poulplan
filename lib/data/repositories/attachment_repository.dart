import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/entities/attachment.dart';
import '../db/app_database.dart';
import '../sync/change_recorder.dart';

/// Attachments: synchronized metadata (`attachments`) and the files kept on
/// this device under [directory] (`<id>/<name>`), tracked in
/// `attachment_files`.
class AttachmentRepository {
  AttachmentRepository(
    this._db, {
    required this.directory,
    this.recorder,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Directory directory;
  final ChangeRecorder? recorder;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  int _now() => _clock().toUtc().millisecondsSinceEpoch;

  Future<void> _changed(String id) async =>
      recorder?.record('attachment', [id]);

  File file(Attachment a) =>
      File(p.join(directory.path, a.id, safeFileName(a.name)));

  Directory _folder(String id) => Directory(p.join(directory.path, id));

  Attachment _toEntity(AttachmentRow r, AttachmentFileRow? f) => Attachment(
    id: r.id,
    eventId: r.eventId,
    name: r.name,
    mimeType: r.mimeType,
    size: r.size,
    stored: f?.stored ?? false,
    keepOffline: f?.keepOffline ?? false,
    uploaded: f?.uploaded ?? false,
  );

  JoinedSelectStatement<HasResultSet, dynamic> _joined() =>
      _db.select(_db.attachments).join([
        leftOuterJoin(
          _db.attachmentFiles,
          _db.attachmentFiles.attachmentId.equalsExp(_db.attachments.id),
        ),
      ]);

  Attachment _fromJoin(TypedResult r) => _toEntity(
    r.readTable(_db.attachments),
    r.readTableOrNull(_db.attachmentFiles),
  );

  Stream<List<Attachment>> watchForEvent(String eventId) {
    final query = _joined()
      ..where(
        _db.attachments.eventId.equals(eventId) &
            _db.attachments.deletedAt.isNull(),
      )
      ..orderBy([OrderingTerm.asc(_db.attachments.createdAt)]);
    return query.watch().map((rows) => rows.map(_fromJoin).toList());
  }

  Future<Attachment?> find(String id) async {
    final row = await (_joined()..where(_db.attachments.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromJoin(row);
  }

  /// Not deleted attachments.
  Future<List<Attachment>> all() async =>
      (await (_joined()..where(_db.attachments.deletedAt.isNull())).get())
          .map(_fromJoin)
          .toList();

  /// Deleted attachments this device still has to remove from the cloud.
  Future<List<Attachment>> deletedWithState() async =>
      (await (_joined()..where(
                _db.attachments.deletedAt.isNotNull() &
                    _db.attachmentFiles.attachmentId.isNotNull(),
              ))
              .get())
          .map(_fromJoin)
          .toList();

  Future<void> _setState(
    String id, {
    bool? stored,
    bool? keepOffline,
    bool? uploaded,
  }) async {
    final current = await (_db.select(
      _db.attachmentFiles,
    )..where((f) => f.attachmentId.equals(id))).getSingleOrNull();
    await _db
        .into(_db.attachmentFiles)
        .insertOnConflictUpdate(
          AttachmentFilesCompanion.insert(
            attachmentId: id,
            stored: Value(stored ?? current?.stored ?? false),
            keepOffline: Value(keepOffline ?? current?.keepOffline ?? false),
            uploaded: Value(uploaded ?? current?.uploaded ?? false),
          ),
        );
  }

  Future<Attachment> add(
    String eventId,
    String name,
    List<int> bytes, {
    String? mimeType,
  }) async {
    final id = _uuid.v4();
    final clean = safeFileName(name);
    final now = _now();
    final row = AttachmentsCompanion.insert(
      id: id,
      eventId: eventId,
      name: clean,
      mimeType: mimeType ?? guessMimeType(clean),
      size: bytes.length,
      createdAt: now,
      updatedAt: now,
    );
    await _writeFile(id, clean, bytes);
    await _db.into(_db.attachments).insert(row);
    await _setState(id, stored: true);
    await _changed(id);
    return (await find(id))!;
  }

  Future<void> _writeFile(String id, String name, List<int> bytes) async {
    final target = File(p.join(directory.path, id, safeFileName(name)));
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  }

  /// Keeps [bytes] as the local file of [id] (download, restore).
  /// [uploaded]: whether the cloud already has this content.
  Future<void> storeFile(
    String id,
    List<int> bytes, {
    required bool uploaded,
  }) async {
    final row = await (_db.select(
      _db.attachments,
    )..where((a) => a.id.equals(id))).getSingle();
    await _writeFile(id, row.name, bytes);
    await _setState(id, stored: true, uploaded: uploaded);
  }

  Future<void> markUploaded(String id) => _setState(id, uploaded: true);

  Future<void> setKeepOffline(String id, bool keep) =>
      _setState(id, keepOffline: keep);

  /// Removes the local copy (the cloud still has it).
  Future<void> forgetLocalCopy(String id) async {
    final folder = _folder(id);
    if (folder.existsSync()) await folder.delete(recursive: true);
    await _setState(id, stored: false);
  }

  /// Deletes the attachment everywhere: tombstone (synchronized) and local
  /// file; the state row stays until the cloud copy is removed.
  Future<void> delete(String id) async {
    final now = _now();
    await (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    final folder = _folder(id);
    if (folder.existsSync()) await folder.delete(recursive: true);
    await _setState(id, stored: false);
    await _changed(id);
  }

  /// The cloud copy of a deleted attachment is gone: forget it (and the
  /// local file, when the deletion came from another device).
  Future<void> forgetDeleted(String id) async {
    final folder = _folder(id);
    if (folder.existsSync()) await folder.delete(recursive: true);
    await (_db.delete(
      _db.attachmentFiles,
    )..where((f) => f.attachmentId.equals(id))).go();
  }

  /// Local copies that can be freed: in the cloud and not kept offline.
  Future<List<Attachment>> _freeable() async => (await all())
      .where((a) => a.stored && a.uploaded && !a.keepOffline)
      .toList();

  Future<int> freeableBytes() async =>
      (await _freeable()).fold<int>(0, (sum, a) => sum + a.size);

  /// Frees the local copies of [freeableBytes]; returns the bytes freed.
  Future<int> freeLocalCopies() async {
    var freed = 0;
    for (final a in await _freeable()) {
      await forgetLocalCopy(a.id);
      freed += a.size;
    }
    return freed;
  }

  /// Size of the files on this device.
  Future<int> localBytes() async => (await all())
      .where((a) => a.stored)
      .fold<int>(0, (sum, a) => sum + a.size);
}
