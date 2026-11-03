import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/time/device_time_zone.dart';
import '../../../data/providers.dart';
import '../../../domain/calendar/day.dart';
import '../../../domain/editing/event_draft.dart';
import '../../../domain/entities/calendar_event.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../calendar/providers/calendar_providers.dart';

/// Default start of a new event on [day]: next full hour today, else 09:00.
int defaultStartMinute(Day day, Day today, DateTime nowLocal) {
  if (day != today) return 9 * 60;
  return ((nowLocal.hour + 1) * 60).clamp(0, 23 * 60);
}

/// Saves a new event from [draft] (already validated).
Future<CalendarEvent> createFromDraft(WidgetRef ref, EventDraft draft) {
  final times = draft.resolve();
  final blank = RegExp(r'^\s*$');
  return ref
      .read(eventRepositoryProvider)
      .create(
        title: draft.title.trim(),
        description: draft.description,
        categoryId: draft.categoryId,
        color: draft.color,
        location: blank.hasMatch(draft.location ?? '')
            ? null
            : draft.location!.trim(),
        videoLink: blank.hasMatch(draft.videoLink ?? '')
            ? null
            : draft.videoLink!.trim(),
        busy: draft.busy,
        allDay: draft.allDay,
        start: times.start,
        end: times.end,
        timeZone: draft.timeZone,
        rrule: draft.rrule,
        holidayRule: draft.holidayRule,
        reminders: (draft.reminders.toSet().toList()..sort()),
      );
}

/// Small dialog to create an event with just a title.
Future<void> showQuickCreate(
  BuildContext context,
  WidgetRef ref, {
  required Day day,
  int? startMinute,
  bool allDay = false,
}) async {
  final zone = ref.read(deviceTimeZoneProvider);
  final minute =
      startMinute ??
      defaultStartMinute(
        day,
        ref.read(todayProvider),
        ref.read(localTimeProvider)(DateTime.now().toUtc()),
      );
  final defaultReminder = ref.read(settingsProvider).defaultReminder;
  final draft = allDay
      ? EventDraft.newAllDay(day: day, timeZone: zone)
      : (EventDraft.newTimed(day: day, startMinute: minute, timeZone: zone)
          ..reminders = [?defaultReminder]);
  final moreOptions = await showDialog<bool>(
    context: context,
    builder: (context) => _QuickCreateDialog(draft: draft),
  );
  if (moreOptions == true && context.mounted) {
    await context.push(Routes.newEvent, extra: draft);
  }
}

class _QuickCreateDialog extends ConsumerStatefulWidget {
  const _QuickCreateDialog({required this.draft});

  final EventDraft draft;

  @override
  ConsumerState<_QuickCreateDialog> createState() => _QuickCreateDialogState();
}

class _QuickCreateDialogState extends ConsumerState<_QuickCreateDialog> {
  final _title = TextEditingController();
  String? _error;

  EventDraft get _draft => widget.draft;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _draft.title = _title.text;
    if (_draft.validate() == DraftError.emptyTitle) {
      setState(() => _error = AppLocalizations.of(context).errorEmptyTitle);
      return;
    }
    final navigator = Navigator.of(context);
    await createFromDraft(ref, _draft);
    navigator.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final when = _draft.allDay
        ? l10n.allDay
        : '${formatMinutes(_draft.startMinute)} – '
              '${formatMinutes(_draft.endMinute)}';

    return AlertDialog(
      // Scrolls when the on-screen keyboard leaves little room.
      scrollable: true,
      title: Text(l10n.newEvent),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.fieldTitle,
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            Text('${formatDayLong(context, _draft.startDay)} · $when'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.allDay),
              value: _draft.allDay,
              onChanged: (v) => setState(() {
                _draft.allDay = v;
                // Timed default reminders make no sense for all-day events.
                _draft.reminders = v
                    ? []
                    : [?ref.read(settingsProvider).defaultReminder];
              }),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: Color(c.color)),
                    label: Text(c.name),
                    selected: _draft.categoryId == c.id,
                    onSelected: (selected) => setState(
                      () => _draft.categoryId = selected ? c.id : null,
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.tune),
                label: Text(l10n.moreOptions),
                onPressed: () {
                  _draft.title = _title.text;
                  Navigator.of(context).pop(true);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
