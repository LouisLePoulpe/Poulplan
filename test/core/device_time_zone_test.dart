import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/core/time/device_time_zone.dart';
import 'package:timezone/data/latest.dart' as tzdata;

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
}
