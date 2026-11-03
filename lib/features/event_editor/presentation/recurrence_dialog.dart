import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/input/digits_formatter.dart';
import '../../../core/format/formatters.dart';
import '../../../domain/calendar/day.dart';
import '../../../domain/recurrence/recurrence_rule.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'recurrence_text.dart';

/// Result of the recurrence picker: [rule] null means "does not repeat".
typedef RecurrenceChoice = ({RecurrenceRule? rule});

/// Lets the user pick a preset or build a custom rule for a series starting
/// on [start]. Returns null when cancelled.
Future<RecurrenceChoice?> showRecurrencePicker(
  BuildContext context, {
  required Day start,
  RecurrenceRule? current,
}) async {
  final l10n = AppLocalizations.of(context);
  final locale = localeOf(context);
  final presets = <RecurrenceRule?>[
    null,
    const RecurrenceRule(frequency: Frequency.daily),
    const RecurrenceRule(
      frequency: Frequency.daily,
      byDay: [ByDay(1), ByDay(2), ByDay(3), ByDay(4), ByDay(5)],
    ),
    const RecurrenceRule(frequency: Frequency.weekly),
    const RecurrenceRule(frequency: Frequency.monthly),
    monthlyByPosition(start),
    ?monthlyByLastWeekday(start),
    const RecurrenceRule(frequency: Frequency.yearly),
  ];
  final picked = await showDialog<Object>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.fieldRecurrence),
      children: [
        RadioGroup<String>(
          groupValue: current?.toString() ?? '',
          onChanged: (key) =>
              Navigator.of(context)
                  .pop(key == '' ? 'none' : RecurrenceRule.parse(key!)),
          child: Column(
            children: [
              for (final rule in [
                ...presets,
                if (current != null && !presets.contains(current)) current,
              ])
                RadioListTile<String>(
                  value: rule?.toString() ?? '',
                  title: Text(
                    rule == null
                        ? l10n.recurrenceNone
                        : describeRule(rule, start, locale),
                  ),
                ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text(l10n.recurrenceCustom),
          onTap: () => Navigator.of(context).pop('custom'),
        ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return null;
  if (picked == 'none') return (rule: null);
  if (picked is RecurrenceRule) return (rule: picked);
  final custom = await showDialog<RecurrenceRule>(
    context: context,
    builder: (context) => _CustomRuleDialog(start: start, initial: current),
  );
  return custom == null ? null : (rule: custom);
}

enum _MonthlyMode { dayOfMonth, position, last }

enum _EndMode { never, count, until }

class _CustomRuleDialog extends StatefulWidget {
  const _CustomRuleDialog({required this.start, this.initial});

  final Day start;
  final RecurrenceRule? initial;

  @override
  State<_CustomRuleDialog> createState() => _CustomRuleDialogState();
}

class _CustomRuleDialogState extends State<_CustomRuleDialog> {
  late Frequency _frequency = widget.initial?.frequency ?? Frequency.weekly;
  late final _interval = TextEditingController(
    text: '${widget.initial?.interval ?? 1}',
  );
  late Set<int> _weekdays = {
    ...?widget.initial?.byDay.map((b) => b.weekday),
    if (widget.initial?.byDay.isEmpty ?? true) widget.start.weekday,
  };
  late _MonthlyMode _monthly = switch (widget.initial?.byDay.firstOrNull) {
    ByDay(position: -1) => _MonthlyMode.last,
    ByDay(position: final p?) when p > 0 => _MonthlyMode.position,
    _ => _MonthlyMode.dayOfMonth,
  };
  late _EndMode _end = widget.initial?.count != null
      ? _EndMode.count
      : widget.initial?.until != null
      ? _EndMode.until
      : _EndMode.never;
  late final _count = TextEditingController(
    text: '${widget.initial?.count ?? 10}',
  );
  late Day _until = widget.initial?.until ?? widget.start.addMonths(3);

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  RecurrenceRule _build() {
    final start = widget.start;
    final interval = (int.tryParse(_interval.text) ?? 1).clamp(1, 999);
    final byDay = switch (_frequency) {
      Frequency.weekly => [
        for (final w in _weekdays.toList()..sort()) ByDay(w),
      ],
      Frequency.monthly => switch (_monthly) {
        _MonthlyMode.dayOfMonth => const <ByDay>[],
        _MonthlyMode.position => monthlyByPosition(start).byDay,
        _MonthlyMode.last => [ByDay(start.weekday, -1)],
      },
      _ => const <ByDay>[],
    };
    return RecurrenceRule(
      frequency: _frequency,
      interval: interval,
      byDay: byDay,
      count: _end == _EndMode.count
          ? (int.tryParse(_count.text) ?? 1).clamp(1, 9999)
          : null,
      until: _end == _EndMode.until ? _until : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = localeOf(context);
    final start = widget.start;
    final weekdayShort = DateFormat.E(locale);
    final weekdayLong = DateFormat.EEEE(locale).format(start.toLocalMidnight());
    final lastAllowed = start.addDays(7).month != start.month;
    final units = {
      Frequency.daily: l10n.unitDays,
      Frequency.weekly: l10n.unitWeeks,
      Frequency.monthly: l10n.unitMonths,
      Frequency.yearly: l10n.unitYears,
    };

    return AlertDialog(
      title: Text(l10n.recurrenceCustom),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.recurrenceEvery),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: _interval,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [DigitsInputFormatter()],
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<Frequency>(
                    value: _frequency,
                    onChanged: (f) => setState(() => _frequency = f!),
                    items: [
                      for (final f in Frequency.values)
                        DropdownMenuItem(value: f, child: Text(units[f]!)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_frequency == Frequency.weekly)
                Wrap(
                  spacing: 4,
                  children: [
                    for (var w = 1; w <= 7; w++)
                      FilterChip(
                        label: Text(
                          weekdayShort.format(DateTime(2026, 1, 4 + w)),
                        ),
                        selected: _weekdays.contains(w),
                        onSelected: (on) => setState(() {
                          _weekdays = {..._weekdays};
                          on ? _weekdays.add(w) : _weekdays.remove(w);
                          if (_weekdays.isEmpty) _weekdays.add(start.weekday);
                        }),
                      ),
                  ],
                ),
              if (_frequency == Frequency.monthly)
                RadioGroup<_MonthlyMode>(
                  groupValue: _monthly,
                  onChanged: (m) => setState(() => _monthly = m!),
                  child: Column(
                    children: [
                      RadioListTile(
                        value: _MonthlyMode.dayOfMonth,
                        title: Text(l10n.monthlyOnDay(start.day)),
                      ),
                      RadioListTile(
                        value: _MonthlyMode.position,
                        title: Text(
                          describeRule(
                            monthlyByPosition(start),
                            start,
                            locale,
                          ).replaceFirst('Tous les mois ', ''),
                        ),
                      ),
                      if (lastAllowed)
                        RadioListTile(
                          value: _MonthlyMode.last,
                          title: Text(l10n.monthlyOnLast(weekdayLong)),
                        ),
                    ],
                  ),
                ),
              const Divider(),
              Text(l10n.recurrenceEnds),
              RadioGroup<_EndMode>(
                groupValue: _end,
                onChanged: (e) => setState(() => _end = e!),
                child: Column(
                  children: [
                    RadioListTile(
                      value: _EndMode.never,
                      title: Text(l10n.recurrenceNever),
                    ),
                    RadioListTile(
                      value: _EndMode.count,
                      title: Row(
                        children: [
                          Text(l10n.recurrenceAfter),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 56,
                            child: TextField(
                              controller: _count,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [DigitsInputFormatter()],
                              textAlign: TextAlign.center,
                              onTap: () =>
                                  setState(() => _end = _EndMode.count),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.recurrenceTimes),
                        ],
                      ),
                    ),
                    RadioListTile(
                      value: _EndMode.until,
                      title: Row(
                        children: [
                          Text(l10n.recurrenceUntil),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _until.toLocalMidnight(),
                                firstDate: start.toLocalMidnight(),
                                lastDate: DateTime(2200),
                              );
                              if (picked != null) {
                                setState(() {
                                  _until = Day.fromDateTime(picked);
                                  _end = _EndMode.until;
                                });
                              }
                            },
                            child: Text(formatDayShort(context, _until)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Text(
                describeRule(_build(), start, locale),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_build()),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
