import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';

import '../../domain/entities/attachment.dart';
import '../repositories/attachment_repository.dart';

class AttachmentNotFoundException implements Exception {
  const AttachmentNotFoundException(this.path);

  final String path;
}

/// The file is neither on this device nor reachable in the cloud.
class AttachmentUnavailableException implements Exception {
  const AttachmentUnavailableException();
}

/// Cloud storage of the attachment files.
abstract class AttachmentRemote {
  Future<void> upload(String path, List<int> bytes, String mimeType);

  /// Throws [AttachmentNotFoundException] when there is no such file.
  Future<List<int>> download(String path);

  Future<void> remove(List<String> paths);
}

class SupabaseAttachmentRemote implements AttachmentRemote {
  SupabaseAttachmentRemote(this._client);

  final SupabaseClient _client;
  static const bucket = 'poulplan-attachments';

  @override
  Future<void> upload(String path, List<int> bytes, String mimeType) => _client
      .storage
      .from(bucket)
      .uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );

  @override
  Future<List<int>> download(String path) async {
    try {
      return await _client.storage.from(bucket).download(path);
    } on StorageException catch (e) {
      if (e.statusCode == '404' || e.statusCode == '400') {
        throw AttachmentNotFoundException(path);
      }
      rethrow;
    }
  }

  @override
  Future<void> remove(List<String> paths) =>
      _client.storage.from(bucket).remove(paths);
}

/// Moves the files between this device and the cloud: sends the new ones,
/// downloads the ones kept offline, removes the deleted ones. Each step is
/// retried at the next run when it fails (offline).
class AttachmentTransfer {
  AttachmentTransfer(this._repository, this._remote, {required this.userId});

  final AttachmentRepository _repository;
  final AttachmentRemote _remote;
  final String userId;

  String pathOf(Attachment a) => '$userId/${a.eventId}/${a.id}';

  Future<void> run() async {
    for (final a in await _repository.all()) {
      try {
        if (a.stored && !a.uploaded) {
          final bytes = await _repository.file(a).readAsBytes();
          await _remote.upload(pathOf(a), bytes, a.mimeType);
          await _repository.markUploaded(a.id);
        } else if (a.keepOffline && !a.stored) {
          await _download(a);
        }
      } on AttachmentNotFoundException {
        // Not sent yet by the device that has it: next time.
      } catch (e) {
        debugPrint('Attachment transfer failed for ${a.id}: $e');
      }
    }
    for (final a in await _repository.deletedWithState()) {
      try {
        await _remote.remove([pathOf(a)]);
        await _repository.forgetDeleted(a.id);
      } catch (e) {
        debugPrint('Attachment removal failed for ${a.id}: $e');
      }
    }
  }

  Future<File> _download(Attachment a) async {
    final bytes = await _remote.download(pathOf(a));
    await _repository.storeFile(a.id, bytes, uploaded: true);
    return _repository.file(a);
  }

  /// The local file of [a], downloaded first when needed.
  Future<File> fetch(Attachment a) async {
    if (a.stored && _repository.file(a).existsSync()) {
      return _repository.file(a);
    }
    try {
      return await _download(a);
    } on AttachmentNotFoundException {
      throw const AttachmentUnavailableException();
    }
  }
}
