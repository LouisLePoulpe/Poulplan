import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/security/pin.dart';

@immutable
class AppLockState {
  const AppLockState({
    this.pinHash,
    this.biometric = false,
    this.delay = const Duration(minutes: 5),
    this.locked = false,
  });

  /// Hash of the PIN (see `hashPin`), null when the lock is off.
  final String? pinHash;
  final bool biometric;

  /// Time in the background after which the app locks again.
  final Duration delay;
  final bool locked;

  bool get enabled => pinHash != null;

  AppLockState copyWith({
    String? Function()? pinHash,
    bool? biometric,
    Duration? delay,
    bool? locked,
  }) => AppLockState(
    pinHash: pinHash != null ? pinHash() : this.pinHash,
    biometric: biometric ?? this.biometric,
    delay: delay ?? this.delay,
    locked: locked ?? this.locked,
  );
}

const _pinKey = 'lock_pin';
const _biometricKey = 'lock_biometric';
const _delayKey = 'lock_delay_minutes';

/// Lock settings read before the first frame, so that the app never shows
/// the calendar before the lock screen. Overridden in `main()`.
final initialLockStateProvider = Provider<AppLockState>(
  (ref) => const AppLockState(),
);

Future<AppLockState> loadLockState(SettingsRepository settings) async {
  final pin = await settings.getValue(_pinKey);
  return AppLockState(
    pinHash: pin?.isEmpty ?? true ? null : pin,
    biometric: await settings.getValue(_biometricKey) == 'true',
    delay: Duration(
      minutes: int.tryParse(await settings.getValue(_delayKey) ?? '') ?? 5,
    ),
    locked: pin?.isNotEmpty ?? false,
  );
}

final lockControllerProvider = NotifierProvider<LockController, AppLockState>(
  LockController.new,
);

/// Optional lock of the app by PIN, or biometrics on Android. It hides the
/// app's screens only: widgets and notifications stay visible.
class LockController extends Notifier<AppLockState> {
  DateTime? _leftAt;
  int _failures = 0;
  DateTime? _blockedUntil;

  static const maxFailures = 5;
  static const blockDuration = Duration(seconds: 30);

  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  @override
  AppLockState build() {
    final listener = AppLifecycleListener(onStateChange: _onLifecycle);
    ref.onDispose(listener.dispose);
    return ref.read(initialLockStateProvider);
  }

  void _onLifecycle(AppLifecycleState lifecycle) {
    if (!state.enabled) return;
    if (lifecycle == AppLifecycleState.resumed) {
      if (shouldLockOnResume(_leftAt, DateTime.now(), state.delay)) {
        state = state.copyWith(locked: true);
      }
      _leftAt = null;
    } else if (lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.paused) {
      _leftAt ??= DateTime.now();
    }
  }

  /// Seconds to wait after too many wrong PINs, 0 when allowed.
  int get secondsBlocked {
    final until = _blockedUntil;
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds;
    return left > 0 ? left + 1 : 0;
  }

  Future<bool> unlockWithPin(String pin) async {
    if (secondsBlocked > 0) return false;
    final hash = state.pinHash;
    if (hash == null || verifyPin(pin, hash)) {
      _failures = 0;
      state = state.copyWith(locked: false);
      return true;
    }
    if (++_failures >= maxFailures) {
      _failures = 0;
      _blockedUntil = DateTime.now().add(blockDuration);
    }
    return false;
  }

  /// Android only: fingerprint, face or the device's own lock.
  static Future<bool> biometricsAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await LocalAuthentication().isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlockWithBiometrics(String reason) async {
    if (!state.biometric) return false;
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      if (ok) state = state.copyWith(locked: false);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> enable(String pin) async {
    final hash = hashPin(pin);
    await _settings.setValue(_pinKey, hash);
    state = state.copyWith(pinHash: () => hash, locked: false);
  }

  /// Turns the lock off; needs the current PIN.
  Future<bool> disable(String currentPin) async {
    final hash = state.pinHash;
    if (hash != null && !verifyPin(currentPin, hash)) return false;
    await _settings.setValue(_pinKey, '');
    await _settings.setValue(_biometricKey, 'false');
    state = state.copyWith(pinHash: () => null, biometric: false);
    return true;
  }

  Future<void> setBiometric(bool value) async {
    await _settings.setValue(_biometricKey, '$value');
    state = state.copyWith(biometric: value);
  }

  Future<void> setDelay(Duration delay) async {
    await _settings.setValue(_delayKey, '${delay.inMinutes}');
    state = state.copyWith(delay: delay);
  }

  void lockNow() {
    if (state.enabled) state = state.copyWith(locked: true);
  }
}
