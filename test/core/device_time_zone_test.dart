import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/core/time/device_time_zone.dart';
import 'package:poulplan/features/calendar/providers/calendar_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  Never fail() => throw Exception('missing');

  String? detect({
    String? tzEnv,
    String Function()? link,
    List<int> Function()? localtime,
    String Function()? timezoneFile,
    Map<String, List<int>> zoneinfo = const {},
    Set<String> clock = const {'Europe/Paris', 'Europe/Brussels'},
  }) => linuxZoneFromSystem(
    tzEnv: tzEnv,
    readLocaltimeLink: link ?? fail,
    readLocaltimeBytes: localtime ?? fail,
    readTimezoneFile: timezoneFile ?? fail,
    readZoneinfo: (zone) => zoneinfo[zone],
    listZoneinfo: () => zoneinfo.keys,
    matchesLocalClock: clock.contains,
  );

  test('TZ environment variable wins', () {
    expect(
      detect(
        tzEnv: ':Europe/Paris',
        link: () => '/usr/share/zoneinfo/Asia/Tokyo',
      ),
      'Europe/Paris',
    );
  });

  test('then the /etc/localtime symlink', () {
    expect(
      detect(link: () => '../usr/share/zoneinfo/Europe/Paris'),
      'Europe/Paris',
    );
  });

  test('/etc/localtime copied as a file (distrobox) with a stale '
      '/etc/timezone: the zone is found by content', () {
    expect(
      detect(
        localtime: () => [1, 2, 3],
        timezoneFile: () => 'Etc/UTC\n',
        zoneinfo: {
          'Etc/UTC': [9, 9],
          'Europe/Paris': [1, 2, 3],
          'posix/Europe/Paris': [1, 2, 3],
        },
      ),
      'Europe/Paris',
    );
  });

  test('/etc/timezone is used only when it matches the local clock', () {
    expect(detect(timezoneFile: () => 'Europe/Brussels\n'), 'Europe/Brussels');
    expect(detect(timezoneFile: () => 'Etc/UTC\n'), isNull);
  });

  test('unknown or inconsistent zones give null', () {
    expect(detect(tzEnv: 'Nowhere/Land'), isNull);
    expect(detect(link: () => '/usr/share/zoneinfo/Asia/Tokyo'), isNull);
  });

  group('the zone follows the device while the app runs', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          initialDeviceTimeZoneProvider.overrideWithValue('Europe/Paris'),
        ],
      );
      addTearDown(container.dispose);
      // `refresh` changes the global tz.local: restore it for the next test.
      addTearDown(() => tz.setLocalLocation(tz.getLocation('Europe/Paris')));
    });

    Future<bool> refresh(String? detected) => container
        .read(deviceZoneProvider.notifier)
        .refresh(detect: () async => detected);

    test('starts with the zone read at startup', () {
      expect(container.read(deviceTimeZoneProvider), 'Europe/Paris');
    });

    test('a new zone updates the provider, the display and tz.local', () async {
      expect(await refresh('America/New_York'), isTrue);
      expect(container.read(deviceTimeZoneProvider), 'America/New_York');
      expect(
        container.read(displayLocationProvider).name,
        'America/New_York',
      );
      expect(tz.local.name, 'America/New_York');
      // 12:00 UTC on 21 November is 07:00 in New York (EST) — it was 13:00
      // in Paris.
      final local = container.read(localTimeProvider)(
        DateTime.utc(2026, 11, 21, 12),
      );
      expect((local.hour, local.minute), (7, 0));
    });

    test('the same zone changes nothing', () async {
      expect(await refresh('Europe/Paris'), isFalse);
      expect(container.read(deviceTimeZoneProvider), 'Europe/Paris');
    });

    test('an undetectable or unknown zone keeps the current one', () async {
      expect(await refresh(null), isFalse);
      expect(await refresh('Mars/Olympus_Mons'), isFalse);
      expect(container.read(deviceTimeZoneProvider), 'Europe/Paris');
    });

    test('today is recomputed in the new display zone', () async {
      await refresh('Pacific/Kiritimati'); // UTC+14, the first to see a day
      final after = container.read(todayProvider);
      final expected = tz.TZDateTime.now(tz.getLocation('Pacific/Kiritimati'));
      expect((after.year, after.month, after.day), (
        expected.year,
        expected.month,
        expected.day,
      ));
    });
  });
}
