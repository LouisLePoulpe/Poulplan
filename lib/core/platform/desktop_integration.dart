import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Linux desktop integration: window kept running when closed (so that
/// reminders keep working) and session autostart.
abstract final class DesktopIntegration {
  static const _channel = MethodChannel('org.poulapp.poulplan/window');
  static const _desktopFile = 'org.poulapp.poulplan.desktop';

  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Autostart is managed by the sandbox portal in Flatpak builds.
  static bool get canManageAutostart =>
      isLinux && Platform.environment['FLATPAK_ID'] == null;

  static Future<void> _invoke(String method, [Object? arguments]) async {
    if (!isLinux) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Tests and other embedders.
    }
  }

  static Future<void> setHideOnClose(bool value) =>
      _invoke('setHideOnClose', value);

  static Future<void> showWindow() => _invoke('show');

  static Future<void> quit() => _invoke('quit');

  static File _autostartFile() {
    final config =
        Platform.environment['XDG_CONFIG_HOME'] ??
        p.join(Platform.environment['HOME'] ?? '', '.config');
    return File(p.join(config, 'autostart', _desktopFile));
  }

  static bool get autostartEnabled =>
      canManageAutostart && _autostartFile().existsSync();

  /// Starts Poulplan hidden (`--background`) when the session opens.
  static Future<void> setAutostart(bool enabled) async {
    if (!canManageAutostart) return;
    final file = _autostartFile();
    if (!enabled) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=Poulplan\n'
      'Comment=Rappels du calendrier Poulplan\n'
      'Icon=org.poulapp.poulplan\n'
      'Exec="${Platform.resolvedExecutable}" --background\n'
      'X-GNOME-Autostart-enabled=true\n'
      'X-KDE-autostart-after=panel\n'
      'NoDisplay=true\n',
    );
  }
}
