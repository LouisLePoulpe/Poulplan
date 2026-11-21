import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Zone read at startup (overridden in `main()`).
final initialDeviceTimeZoneProvider = Provider<String>((ref) => 'UTC');

/// The device's current zone, kept up to date while the app runs: a phone
/// crossing time zones keeps the app alive in the background, so reading the
/// zone once at startup is not enough (see [DeviceTimeZoneWatcher]).
class DeviceTimeZoneNotifier extends Notifier<String> {
  @override
  String build() => ref.read(initialDeviceTimeZoneProvider);

  /// Re-reads the device's zone and, if it changed, switches the display zone
  /// of the whole app. Returns whether it changed. A failed detection keeps
  /// the current zone.
  Future<bool> refresh({
    Future<String?> Function() detect = detectDeviceTimeZone,
  }) async {
    final zone = await detect();
    if (zone == null || zone == state) return false;
    if (tz.timeZoneDatabase.locations[zone] == null) return false;
    tz.setLocalLocation(tz.getLocation(zone));
    state = zone;
    return true;
  }
}

final deviceZoneProvider = NotifierProvider<DeviceTimeZoneNotifier, String>(
  DeviceTimeZoneNotifier.new,
);

/// IANA identifier of the device's time zone (e.g. `Europe/Paris`).
///
/// Everything that displays or plans times depends on this provider, so a
/// change of zone refreshes the views, the reminders and the widgets. Tests
/// override it with a fixed value.
final deviceTimeZoneProvider = Provider<String>(
  (ref) => ref.watch(deviceZoneProvider),
);

/// Re-reads the device's zone when the app comes back to the foreground and
/// every minute while it runs (desktop sessions and open apps get no event
/// when the zone changes).
class DeviceTimeZoneWatcher {
  DeviceTimeZoneWatcher(this._ref);

  final Ref _ref;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;

  void start() {
    _lifecycle ??= AppLifecycleListener(onResume: check);
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => check());
  }

  Future<void> check() async {
    try {
      await _ref.read(deviceZoneProvider.notifier).refresh();
    } catch (error) {
      debugPrint('Time zone check failed: $error');
    }
  }

  void dispose() {
    _lifecycle?.dispose();
    _timer?.cancel();
  }
}

final deviceTimeZoneWatcherProvider = Provider<DeviceTimeZoneWatcher>((ref) {
  final watcher = DeviceTimeZoneWatcher(ref);
  ref.onDispose(watcher.dispose);
  return watcher;
});

/// Loads the time zone database and returns the device's IANA zone.
Future<String> initTimeZones() async {
  tzdata.initializeTimeZones();
  // Unknown zone: keep UTC rather than not starting.
  final zone = await detectDeviceTimeZone() ?? 'UTC';
  tz.setLocalLocation(tz.getLocation(zone));
  return zone;
}

/// The device's IANA zone right now, or null if it cannot be determined.
/// Needs [tzdata.initializeTimeZones] to have run.
Future<String?> detectDeviceTimeZone() async {
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
  return null;
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
