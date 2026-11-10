import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

/// Files chosen by the user: open (both platforms through file_selector),
/// save (Android: system « create document », Linux: save dialog).
class FileExchange {
  static const _android = MethodChannel('org.poulapp.poulplan/android');

  /// Returns false when the user cancelled.
  static Future<bool> save({
    required String name,
    required String mime,
    required String extension,
    required List<int> bytes,
  }) async {
    if (Platform.isAndroid) {
      return await _android.invokeMethod<bool>('saveDocument', {
            'name': name,
            'mime': mime,
            'bytes': Uint8List.fromList(bytes),
          }) ??
          false;
    }
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(label: extension, extensions: [extension]),
      ],
    );
    if (location == null) return false;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return true;
  }

  /// One file, or null when cancelled.
  static Future<({String name, Uint8List bytes})?> pick({
    required String label,
    required List<String> extensions,
    required List<String> mimeTypes,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: label,
          extensions: extensions,
          // Android filters by MIME type; Linux by extension.
          mimeTypes: Platform.isAndroid ? mimeTypes : null,
        ),
      ],
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  }

  /// Birthdays of the Android contacts (asks the permission when needed).
  /// Throws a [PlatformException] `PERMISSION_DENIED` when refused.
  static Future<List<({String name, String date})>> contactBirthdays() async {
    final rows =
        await _android.invokeListMethod<Map<Object?, Object?>>(
          'contactBirthdays',
        ) ??
        const [];
    return [
      for (final r in rows)
        (name: r['name']! as String, date: r['date']! as String),
    ];
  }

  /// Opens [path] with the default application.
  static Future<void> open(String path, String mimeType) async {
    if (Platform.isAndroid) {
      await _android.invokeMethod('openFile', {'path': path, 'mime': mimeType});
      return;
    }
    // In a development distrobox, the desktop's opener is on the host.
    final container = Platform.environment['CONTAINER_ID'];
    final result = container == null || container.isEmpty
        ? await Process.run('xdg-open', [path])
        : await Process.run('distrobox-host-exec', ['xdg-open', path]);
    if (result.exitCode != 0) {
      throw PlatformException(code: 'NO_APP', message: '${result.stderr}');
    }
  }

  /// Opens [uri] in another application: on Android a chooser (navigation
  /// apps for a `geo:` link), on Linux the desktop's default (browser).
  static Future<void> openUri(Uri uri, {required String title}) async {
    if (Platform.isAndroid) {
      await _android.invokeMethod('openUri', {'uri': '$uri', 'title': title});
      return;
    }
    final container = Platform.environment['CONTAINER_ID'];
    final result = container == null || container.isEmpty
        ? await Process.run('xdg-open', ['$uri'])
        : await Process.run('distrobox-host-exec', ['xdg-open', '$uri']);
    if (result.exitCode != 0) {
      throw PlatformException(code: 'NO_APP', message: '${result.stderr}');
    }
  }

  /// Free space where [path] is, or null when unknown.
  static Future<int?> freeBytes(String path) async {
    try {
      if (Platform.isAndroid) {
        return await _android.invokeMethod<int>('freeBytes', {'path': path});
      }
      final result = await Process.run('df', ['-Pk', path]);
      final fields = (result.stdout as String)
          .trim()
          .split('\n')
          .last
          .split(RegExp(r'\s+'));
      final kib = int.tryParse(fields.length > 3 ? fields[3] : '');
      return kib == null ? null : kib * 1024;
    } catch (_) {
      return null;
    }
  }
}
