import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/digits_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../lock_controller.dart';

/// Covers the whole app while it is locked.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (ref.read(lockControllerProvider).biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometrics());
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _biometrics() async {
    if (!mounted) return;
    await ref
        .read(lockControllerProvider.notifier)
        .unlockWithBiometrics(AppLocalizations.of(context).lockBiometricReason);
  }

  Future<void> _unlock() async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(lockControllerProvider.notifier);
    final ok = await controller.unlockWithPin(_pin.text);
    if (!mounted || ok) return;
    _pin.clear();
    final blocked = controller.secondsBlocked;
    setState(
      () =>
          _error = blocked > 0 ? l10n.lockBlocked(blocked) : l10n.lockWrongPin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final biometric = ref.watch(lockControllerProvider).biometric;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/poulplan-logo.png',
                    width: 96,
                    height: 96,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.lockTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pin,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    inputFormatters: [
                      const DigitsInputFormatter(),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.lockEnterPin,
                      errorText: _error,
                      counterText: '',
                    ),
                    onSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _unlock,
                    child: Text(l10n.lockUnlock),
                  ),
                  if (biometric) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.fingerprint),
                      label: Text(l10n.lockBiometric),
                      onPressed: _biometrics,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
