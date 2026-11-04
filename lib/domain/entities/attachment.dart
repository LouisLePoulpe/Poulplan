import 'package:meta/meta.dart';

/// A file attached to an event, with what this device has of it.
@immutable
class Attachment {
  const Attachment({
    required this.id,
    required this.eventId,
    required this.name,
    required this.mimeType,
    required this.size,
    this.stored = false,
    this.keepOffline = false,
    this.uploaded = false,
  });

  final String id;
  final String eventId;
  final String name;
  final String mimeType;
  final int size;

  /// The file is on this device.
  final bool stored;

  /// The user asked to keep it on this device.
  final bool keepOffline;

  /// This device has sent it to the cloud.
  final bool uploaded;
}

const _mimeTypes = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'svg': 'image/svg+xml',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'html': 'text/html',
  'ics': 'text/calendar',
  'vcf': 'text/vcard',
  'zip': 'application/zip',
  'odt': 'application/vnd.oasis.opendocument.text',
  'ods': 'application/vnd.oasis.opendocument.spreadsheet',
  'odp': 'application/vnd.oasis.opendocument.presentation',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'mp3': 'audio/mpeg',
  'ogg': 'audio/ogg',
  'mp4': 'video/mp4',
};

/// MIME type from the file name, `application/octet-stream` when unknown.
String guessMimeType(String name) {
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return _mimeTypes[extension] ?? 'application/octet-stream';
}

/// A file name safe to store: no folders, not hidden, not empty.
String safeFileName(String name) {
  final base = name.split(RegExp(r'[/\\]')).last.trim();
  final cleaned = base.replaceAll(RegExp(r'^\.+'), '');
  return cleaned.isEmpty ? 'fichier' : cleaned;
}
