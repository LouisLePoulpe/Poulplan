import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PBKDF2 with HMAC-SHA256 (RFC 8018).
List<int> pbkdf2Sha256(
  List<int> password,
  List<int> salt,
  int iterations,
  int length,
) {
  final hmac = Hmac(sha256, password);
  final result = <int>[];
  for (var block = 1; result.length < length; block++) {
    var u = hmac.convert([
      ...salt,
      block >> 24 & 0xff,
      block >> 16 & 0xff,
      block >> 8 & 0xff,
      block & 0xff,
    ]).bytes;
    final t = List<int>.of(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    result.addAll(t);
  }
  return result.sublist(0, length);
}

const defaultPinIterations = 20000;

bool isValidPin(String pin) => RegExp(r'^\d{4,8}$').hasMatch(pin);

/// `pbkdf2-sha256$<iterations>$<salt>$<hash>` (base64): never the PIN.
String hashPin(
  String pin, {
  List<int>? salt,
  int iterations = defaultPinIterations,
}) {
  final s = salt ?? List.generate(16, (_) => Random.secure().nextInt(256));
  final hash = pbkdf2Sha256(utf8.encode(pin), s, iterations, 32);
  return 'pbkdf2-sha256\$$iterations\$${base64.encode(s)}\$'
      '${base64.encode(hash)}';
}

bool verifyPin(String pin, String stored) {
  final parts = stored.split(r'$');
  if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) return false;
  try {
    final expected = base64.decode(parts[3]);
    final actual = pbkdf2Sha256(
      utf8.encode(pin),
      base64.decode(parts[2]),
      iterations,
      expected.length,
    );
    // Constant time comparison.
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ actual[i];
    }
    return diff == 0;
  } on FormatException {
    return false;
  }
}

/// The app locks again when it comes back after [delay] in the background.
bool shouldLockOnResume(DateTime? pausedAt, DateTime now, Duration delay) =>
    pausedAt != null && now.difference(pausedAt) >= delay;
