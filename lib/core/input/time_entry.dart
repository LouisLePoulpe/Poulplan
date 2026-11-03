import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import 'digits_formatter.dart';

bool get _touch =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Asks for a time: the Material dial on phones, two keyboard fields on
/// desktop (digits accepted from the AZERTY top row without Shift).
Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) {
  if (_touch) return showTimePicker(context: context, initialTime: initial);
  return showDialog<TimeOfDay>(
    context: context,
    builder: (context) => _TimeEntryDialog(initial: initial),
  );
}

class _TimeEntryDialog extends StatefulWidget {
  const _TimeEntryDialog({required this.initial});

  final TimeOfDay initial;

  @override
  State<_TimeEntryDialog> createState() => _TimeEntryDialogState();
}

class _TimeEntryDialogState extends State<_TimeEntryDialog> {
  late final _hour = TextEditingController(
    text: widget.initial.hour.toString().padLeft(2, '0'),
  );
  late final _minute = TextEditingController(
    text: widget.initial.minute.toString().padLeft(2, '0'),
  );
  final _minuteFocus = FocusNode();
  bool _invalid = false;

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final hour = int.tryParse(_hour.text);
    final minute = int.tryParse(_minute.text.isEmpty ? '0' : _minute.text);
    if (hour == null || hour > 23 || minute == null || minute > 59) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(TimeOfDay(hour: hour, minute: minute));
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    FocusNode? focus,
    bool autofocus = false,
    ValueChanged<String>? onChanged,
  }) => SizedBox(
    width: 88,
    child: TextField(
      controller: controller,
      focusNode: focus,
      autofocus: autofocus,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium,
      keyboardType: TextInputType.number,
      inputFormatters: [
        const DigitsInputFormatter(),
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(helperText: label),
      onTap: () => controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      ),
      onChanged: onChanged,
      onSubmitted: (_) => _submit(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _hour.selection = _hour.selection.isValid
        ? _hour.selection
        : TextSelection(baseOffset: 0, extentOffset: _hour.text.length);
    return AlertDialog(
      title: Text(l10n.enterTime),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                _hour,
                l10n.timeHour,
                autofocus: true,
                onChanged: (v) {
                  if (v.length == 2) {
                    _minuteFocus.requestFocus();
                    _minute.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _minute.text.length,
                    );
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              _field(_minute, l10n.timeMinute, focus: _minuteFocus),
            ],
          ),
          if (_invalid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.invalidTime,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}
