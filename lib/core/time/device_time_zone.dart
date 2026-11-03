import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// IANA identifier of the device's time zone (e.g. `Europe/Paris`).
///
/// Overridden in `main()` with the value read at startup.
final deviceTimeZoneProvider = Provider<String>((ref) => 'UTC');

/// Loads the time zone database and returns the device's IANA zone.
Future<String> initTimeZones() async {
  tzdata.initializeTimeZones();
  final zone = await _detectZone();
  tz.setLocalLocation(tz.getLocation(zone));
  return zone;
}

Future<String> _detectZone() async {
  try {
    final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    if (tz.timeZoneDatabase.locations.containsKey(zone)) return zone;
  } catch (error) {
    debugPrint('Time zone plugin failed: $error');
  }
  if (!kIsWeb && Platform.isLinux) {
    final zone = linuxZoneFromSystem(
      tzEnv: Platform.environment['TZ'],
      readLocaltimeLink: () => Link('/etc/localtime').targetSync(),
      readTimezoneFile: () => File('/etc/timezone').readAsStringSync(),
    );
    if (zone != null) return zone;
  }
  // Unknown zone: keep UTC rather than not starting.
  return 'UTC';
}

/// Reads the IANA zone the way glibc does when systemd (`timedatectl`) is not
/// reachable, e.g. in containers or Flatpak sandboxes.
@visibleForTesting
String? linuxZoneFromSystem({
  String? tzEnv,
  required String Function() readLocaltimeLink,
  required String Function() readTimezoneFile,
}) {
  bool known(String zone) => tz.timeZoneDatabase.locations.containsKey(zone);
  final env = tzEnv?.trim().replaceFirst(RegExp('^:'), '');
  if (env != null && known(env)) return env;
  try {
    final target = readLocaltimeLink();
    final match = RegExp(r'zoneinfo/(.+)$').firstMatch(target);
    if (match != null && known(match.group(1)!)) return match.group(1);
  } catch (_) {}
  try {
    final zone = readTimezoneFile().trim();
    if (known(zone)) return zone;
  } catch (_) {}
  return null;
}
