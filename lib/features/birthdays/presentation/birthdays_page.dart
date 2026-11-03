import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/input/digits_formatter.dart';
import '../../../core/format/formatters.dart';
import '../../../data/providers.dart';
import '../../../domain/calendar/day.dart';
import '../../../domain/entities/birthday.dart';
import '../../../l10n/generated/app_localizations.dart';

class BirthdaysPage extends ConsumerWidget {
  const BirthdaysPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final birthdays = ref.watch(birthdaysProvider).value ?? const [];
    final repository = ref.read(birthdayRepositoryProvider);
    final dayMonth = DateFormat.MMMMd(localeOf(context));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.birthdays)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.newBirthday),
        onPressed: () async {
          final result = await _editBirthday(context, null);
          if (result != null) {
            await repository.create(
              name: result.name,
              month: result.month,
              day: result.day,
              birthYear: result.year,
            );
          }
        },
      ),
      body: birthdays.isEmpty
          ? Center(child: Text(l10n.birthdaysEmpty))
          : ListView(
              children: [
                for (final b in birthdays)
                  ListTile(
                    leading: const Icon(Icons.cake_outlined),
                    title: Text(b.name),
                    subtitle: Text(
                      [
                        dayMonth.format(DateTime(2024, b.month, b.day)),
                        if (b.birthYear != null) '${b.birthYear}',
                      ].join(' '),
                    ),
                    onTap: () async {
                      final result = await _editBirthday(context, b);
                      if (result != null) {
                        await repository.update(
                          Birthday(
                            id: b.id,
                            name: result.name,
                            month: result.month,
                            day: result.day,
                            birthYear: result.year,
                            createdAt: b.createdAt,
                            updatedAt: b.updatedAt,
                          ),
                        );
                      }
                    },
                    trailing: IconButton(
                      tooltip: l10n.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => repository.delete(b.id),
                    ),
                  ),
              ],
            ),
    );
  }
}

typedef _BirthdayForm = ({String name, int month, int day, int? year});

Future<_BirthdayForm?> _editBirthday(BuildContext context, Birthday? b) =>
    showDialog(
      context: context,
      builder: (context) => _BirthdayDialog(birthday: b),
    );

class _BirthdayDialog extends StatefulWidget {
  const _BirthdayDialog({this.birthday});

  final Birthday? birthday;

  @override
  State<_BirthdayDialog> createState() => _BirthdayDialogState();
}

class _BirthdayDialogState extends State<_BirthdayDialog> {
  late final _name = TextEditingController(text: widget.birthday?.name);
  late final _year = TextEditingController(
    text: widget.birthday?.birthYear?.toString(),
  );
  late int _month = widget.birthday?.month ?? Day.today().month;
  late int _day = widget.birthday?.day ?? Day.today().day;
  String? _nameError;
  String? _yearError;

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final yearText = _year.text.trim();
    final year = yearText.isEmpty ? null : int.tryParse(yearText);
    setState(() {
      _nameError = name.isEmpty ? l10n.errorEmptyName : null;
      _yearError = yearText.isNotEmpty && (year == null || year < 1800)
          ? l10n.errorInvalidYear
          : null;
    });
    if (_nameError != null || _yearError != null) return;
    Navigator.of(context)
        .pop((name: name, month: _month, day: _day, year: year));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final monthFormat = DateFormat.MMMM(localeOf(context));
    // 2024 is a leap year: 29 February can be chosen.
    final daysInMonth = DateTime(2024, _month + 1, 0).day;
    if (_day > daysInMonth) _day = daysInMonth;

    return AlertDialog(
      title: Text(
        widget.birthday == null ? l10n.newBirthday : l10n.editBirthday,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                DropdownButton<int>(
                  value: _day,
                  onChanged: (v) => setState(() => _day = v!),
                  items: [
                    for (var d = 1; d <= daysInMonth; d++)
                      DropdownMenuItem(value: d, child: Text('$d')),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _month,
                    onChanged: (v) => setState(() => _month = v!),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(monthFormat.format(DateTime(2024, m))),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsInputFormatter()],
              decoration: InputDecoration(
                labelText: l10n.fieldBirthYear,
                errorText: _yearError,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
