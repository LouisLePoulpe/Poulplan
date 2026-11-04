import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/security/pin.dart';

void main() {
  test('a PIN is stored salted and hashed, and verified', () {
    final stored = hashPin('2468', salt: List.filled(16, 7), iterations: 1000);
    expect(stored, isNot(contains('2468')));
    expect(verifyPin('2468', stored), isTrue);
    expect(verifyPin('2469', stored), isFalse);
    expect(verifyPin('2468', 'n/importe/quoi'), isFalse);
    // Same PIN, other salt: other hash.
    expect(
      hashPin('2468', salt: List.filled(16, 8), iterations: 1000),
      isNot(stored),
    );
  });

  test('PBKDF2-HMAC-SHA256 matches the RFC 7914 test vector', () {
    expect(
      pbkdf2Sha256(
        'passwd'.codeUnits,
        'salt'.codeUnits,
        1,
        64,
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
      '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
    );
  });

  test('valid PINs: 4 to 8 digits', () {
    expect(isValidPin('1234'), isTrue);
    expect(isValidPin('12345678'), isTrue);
    expect(isValidPin('123'), isFalse);
    expect(isValidPin('12a4'), isFalse);
  });

  test('locking again after some time in the background', () {
    final paused = DateTime(2026, 11, 4, 10);
    const delay = Duration(minutes: 5);
    expect(shouldLockOnResume(null, paused, delay), isFalse);
    expect(
      shouldLockOnResume(paused, paused.add(const Duration(minutes: 4)), delay),
      isFalse,
    );
    expect(
      shouldLockOnResume(paused, paused.add(const Duration(minutes: 5)), delay),
      isTrue,
    );
    expect(shouldLockOnResume(paused, paused, Duration.zero), isTrue);
  });
}
