import 'package:flutter/material.dart';

import '../../../core/input/digits_formatter.dart';
import '../../../domain/editing/event_draft.dart';
import '../../../domain/reminders/reminders.dart';
import '../../../l10n/generated/app_localizations.dart';

const _timedPresets = [0, 5, 10, 15, 30, 60, 120, 1440, 2880, 10080];
const _allDayPresets = [0, 1440, 2880, 10080];

/// Reminders of the edited event: removable chips and an « Ajouter » menu.
class RemindersEditor extends StatelessWidget {
  const RemindersEditor({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final EventDraft draft;
  final VoidCallback onChanged;

  Future<void> _add(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final presets = draft.allDay ? _allDayPresets : _timedPresets;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.addReminder),
        children: [
          for (final minutes in presets)
            if (!draft.reminders.contains(minutes))
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(minutes),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(describeReminder(minutes, allDay: draft.allDay)),
                ),
              ),
          SimpleDialogOption(
            onPressed: () async {
              final custom = await showDialog<int>(
                context: context,
                builder: (context) => const _CustomReminderDialog(),
              );
              if (context.mounted) Navigator.of(context).pop(custom);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(l10n.recurrenceCustom),
            ),
          ),
        ],
      ),
    );
    if (picked == null || draft.reminders.contains(picked)) return;
    draft.reminders = [...draft.reminders, picked]..sort();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.notifications_outlined),
      title: Text(l10n.fieldReminders),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final minutes in draft.reminders)
              InputChip(
                label: Text(describeReminder(minutes, allDay: draft.allDay)),
                onDeleted: () {
                  draft.reminders = [...draft.reminders]..remove(minutes);
                  onChanged();
                },
                deleteButtonTooltipMessage: l10n.delete,
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(l10n.addReminder),
              onPressed: () => _add(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog();

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  final _value = TextEditingController(text: '20');
  int _unit = 1;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addReminder),
      content: Row(
        children: [
          SizedBox(
            width: 64,
            child: TextField(
              controller: _value,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsInputFormatter()],
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _unit,
            onChanged: (v) => setState(() => _unit = v!),
            items: [
              DropdownMenuItem(value: 1, child: Text(l10n.unitMinutes)),
              DropdownMenuItem(value: 60, child: Text(l10n.unitHours)),
              DropdownMenuItem(value: 1440, child: Text(l10n.unitDays)),
              DropdownMenuItem(value: 10080, child: Text(l10n.unitWeeks)),
            ],
          ),
          const SizedBox(width: 8),
          Text(l10n.reminderBefore),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(_value.text.trim());
            if (value == null || value < 0) return;
            Navigator.of(context).pop(value * _unit);
          },
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
