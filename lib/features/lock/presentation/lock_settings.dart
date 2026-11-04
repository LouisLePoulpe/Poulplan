import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/digits_formatter.dart';
import '../../../domain/security/pin.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../lock_controller.dart';

/// « Sécurité » section of the settings.
class LockSettings extends ConsumerStatefulWidget {
  const LockSettings({super.key});

  @override
  ConsumerState<LockSettings> createState() => _LockSettingsState();
}

class _LockSettingsState extends ConsumerState<LockSettings> {
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    LockController.biometricsAvailable().then((available) {
      if (mounted) setState(() => _biometricsAvailable = available);
    });
  }

  Future<void> _toggle(bool enable) async {
    final controller = ref.read(lockControllerProvider.notifier);
    if (enable) {
      final pin = await showDialog<String>(
        context: context,
        builder: (context) => const _NewPinDialog(),
      );
      if (pin != null) await controller.enable(pin);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final current = await showDialog<String>(
      context: context,
      builder: (context) => _PinDialog(title: l10n.lockCurrentPin),
    );
    if (current == null) return;
    if (!await controller.disable(current) && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.lockWrongPin)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lock = ref.watch(lockControllerProvider);
    final controller = ref.read(lockControllerProvider.notifier);
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: Text(l10n.lockSetting),
          subtitle: Text(l10n.lockSettingSubtitle),
          value: lock.enabled,
          onChanged: _toggle,
        ),
        if (lock.enabled && _biometricsAvailable)
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: Text(l10n.lockBiometricSetting),
            value: lock.biometric,
            onChanged: controller.setBiometric,
          ),
        if (lock.enabled)
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l10n.lockDelaySetting),
            trailing: DropdownButton<int>(
              value: lock.delay.inMinutes,
              onChanged: (m) => controller.setDelay(Duration(minutes: m!)),
              items: [
                for (final m in const [0, 1, 5, 15, 60])
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      m == 0
                          ? l10n.lockDelayImmediate
                          : l10n.lockDelayMinutes(m),
                    ),
                  ),
              ],
            ),
          ),
        if (lock.enabled)
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(l10n.lockNow),
            onTap: controller.lockNow,
          ),
      ],
    );
  }
}

Widget _pinField(
  TextEditingController controller, {
  required String label,
  String? error,
  bool autofocus = false,
  ValueChanged<String>? onSubmitted,
}) => TextField(
  controller: controller,
  autofocus: autofocus,
  obscureText: true,
  keyboardType: TextInputType.number,
  maxLength: 8,
  inputFormatters: [
    const DigitsInputFormatter(),
    FilteringTextInputFormatter.digitsOnly,
  ],
  decoration: InputDecoration(
    labelText: label,
    errorText: error,
    counterText: '',
  ),
  onSubmitted: onSubmitted,
);

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});

  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: _pinField(
        _pin,
        label: l10n.lockEnterPin,
        autofocus: true,
        onSubmitted: (_) => Navigator.pop(context, _pin.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _pin.text),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}

class _NewPinDialog extends StatefulWidget {
  const _NewPinDialog();

  @override
  State<_NewPinDialog> createState() => _NewPinDialogState();
}

class _NewPinDialogState extends State<_NewPinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _pinError;
  String? _confirmError;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _pinError = isValidPin(_pin.text) ? null : l10n.lockPinInvalid;
      _confirmError = _pinError == null && _confirm.text != _pin.text
          ? l10n.lockPinMismatch
          : null;
    });
    if (_pinError == null && _confirmError == null) {
      Navigator.pop(context, _pin.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.lockSetting),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pinField(
            _pin,
            label: l10n.lockNewPin,
            error: _pinError,
            autofocus: true,
          ),
          _pinField(
            _confirm,
            label: l10n.lockConfirmPin,
            error: _confirmError,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.lockForgotHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
