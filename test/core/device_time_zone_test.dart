import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/core/time/device_time_zone.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  String fail() => throw Exception('missing');

  test('TZ environment variable wins', () {
    expect(
      linuxZoneFromSystem(
        tzEnv: ':Europe/Paris',
        readLocaltimeLink: () => '/usr/share/zoneinfo/Asia/Tokyo',
        readTimezoneFile: fail,
      ),
      'Europe/Paris',
    );
  });

  test('falls back to the /etc/localtime symlink', () {
    expect(
      linuxZoneFromSystem(
        readLocaltimeLink: () => '../usr/share/zoneinfo/America/New_York',
        readTimezoneFile: fail,
      ),
      'America/New_York',
    );
  });

  test('then to /etc/timezone, ignoring unknown zones', () {
    expect(
      linuxZoneFromSystem(
        tzEnv: 'Nowhere/Land',
        readLocaltimeLink: fail,
        readTimezoneFile: () => 'Europe/Brussels\n',
      ),
      'Europe/Brussels',
    );
    expect(
      linuxZoneFromSystem(readLocaltimeLink: fail, readTimezoneFile: fail),
      isNull,
    );
  });
}
