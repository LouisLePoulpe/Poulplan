import 'dart:io';

import 'package:collection/collection.dart';
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
    // Containers may report a stale zone (e.g. Etc/UTC from /etc/timezone
    // while the clock follows the host): only trust it if it matches.
    if (_matchesLocalClock(zone)) return zone;
  } catch (error) {
    debugPrint('Time zone plugin failed: $error');
  }
  if (!kIsWeb && Platform.isLinux) {
    const zoneinfo = '/usr/share/zoneinfo';
    final zone = linuxZoneFromSystem(
      tzEnv: Platform.environment['TZ'],
      readLocaltimeLink: () => Link('/etc/localtime').targetSync(),
      readLocaltimeBytes: () => File('/etc/localtime').readAsBytesSync(),
      readTimezoneFile: () => File('/etc/timezone').readAsStringSync(),
      readZoneinfo: (zone) {
        final file = File('$zoneinfo/$zone');
        return file.existsSync() ? file.readAsBytesSync() : null;
      },
      listZoneinfo: () =>
          Directory(zoneinfo)
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .map((f) => f.path.substring(zoneinfo.length + 1)),
      matchesLocalClock: _matchesLocalClock,
    );
    if (zone != null) return zone;
  }
  // Unknown zone: keep UTC rather than not starting.
  return 'UTC';
}

/// Whether [zone] gives the same UTC offsets as the system's local time,
/// now and in six months (so that DST rules agree too).
bool _matchesLocalClock(String zone) {
  final location = tz.timeZoneDatabase.locations[zone];
  if (location == null) return false;
  final now = DateTime.now();
  return [now, now.add(const Duration(days: 182))].every(
    (instant) =>
        tz.TZDateTime.from(instant, location).timeZoneOffset ==
        instant.toLocal().timeZoneOffset,
  );
}

/// Finds the IANA zone when systemd (`timedatectl`) is not reachable, e.g.
/// in containers or Flatpak sandboxes.
///
/// Order: `TZ`, the `/etc/localtime` symlink, the zoneinfo file whose
/// content equals `/etc/localtime` (distrobox copies the host's file and may
/// leave a stale `/etc/timezone`), then `/etc/timezone`. A zone is accepted
/// only if it matches the local clock.
@visibleForTesting
String? linuxZoneFromSystem({
  String? tzEnv,
  required String Function() readLocaltimeLink,
  required List<int> Function() readLocaltimeBytes,
  required String Function() readTimezoneFile,
  required List<int>? Function(String zone) readZoneinfo,
  required Iterable<String> Function() listZoneinfo,
  required bool Function(String zone) matchesLocalClock,
}) {
  bool usable(String zone) =>
      tz.timeZoneDatabase.locations.containsKey(zone) &&
      matchesLocalClock(zone);

  final env = tzEnv?.trim().replaceFirst(RegExp('^:'), '');
  if (env != null && usable(env)) return env;

  try {
    final match = RegExp(r'zoneinfo/(.+)$').firstMatch(readLocaltimeLink());
    if (match != null && usable(match.group(1)!)) return match.group(1);
  } catch (_) {}

  String? timezoneFile;
  try {
    timezoneFile = readTimezoneFile().trim();
  } catch (_) {}

  try {
    final local = readLocaltimeBytes();
    bool same(String zone) {
      final bytes = readZoneinfo(zone);
      return bytes != null && const ListEquality<int>().equals(bytes, local);
    }

    if (timezoneFile != null && usable(timezoneFile) && same(timezoneFile)) {
      return timezoneFile;
    }
    final candidates =
        listZoneinfo()
            .where(
              (z) =>
                  z.contains('/') &&
                  !z.startsWith('posix/') &&
                  !z.startsWith('right/') &&
                  !z.startsWith('Etc/'),
            )
            .toList()
          ..sort();
    for (final zone in candidates) {
      if (usable(zone) && same(zone)) return zone;
    }
  } catch (_) {}

  if (timezoneFile != null && usable(timezoneFile)) return timezoneFile;
  return null;
}
