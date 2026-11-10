import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/input/time_entry.dart';
import '../../../core/time/device_time_zone.dart';
import '../../../data/providers.dart';
import '../../../domain/calendar/day.dart';
import '../../../domain/calendar/day_layout.dart';
import '../../../domain/editing/event_draft.dart';
import '../../../domain/entities/calendar_event.dart';
import '../../../domain/recurrence/recurrence_rule.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../calendar/presentation/event_actions.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../categories/presentation/color_palette.dart';
import 'quick_create.dart';
import '../../maps/presentation/navigation_button.dart';
import '../../maps/presentation/place_search.dart';
import '../../maps/presentation/route_section.dart';
import 'attachments_editor.dart';
import 'recurrence_dialog.dart';
import 'reminders_editor.dart';
import 'recurrence_text.dart';
import 'time_zone_picker.dart';

/// Full editor. Edits [eventId] when given, else creates from [initial].
class EventEditorPage extends ConsumerStatefulWidget {
  const EventEditorPage({super.key, this.eventId, this.initial});

  final String? eventId;
  final EventDraft? initial;

  @override
  ConsumerState<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<EventEditorPage> {
  CalendarEvent? _original;
  EventDraft? _draft;
  bool _notFound = false;
  String? _titleError;
  String? _timeError;
  final _pendingAttachments = <PendingAttachment>[];

  final _title = TextEditingController();
  final _location = TextEditingController();
  final _videoLink = TextEditingController();
  final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _load(widget.eventId!);
    } else {
      final today = ref.read(todayProvider);
      _setDraft(
        widget.initial ??
              EventDraft.newTimed(
                day: today,
                startMinute: defaultStartMinute(
                  today,
                  today,
                  ref.read(localTimeProvider)(DateTime.now().toUtc()),
                ),
                timeZone: ref.read(deviceTimeZoneProvider),
              )
          ..reminders = [?ref.read(settingsProvider).defaultReminder],
      );
    }
  }

  Future<void> _load(String id) async {
    final repository = ref.read(eventRepositoryProvider);
    final event = await repository.findDisplayed(id);
    // An overridden occurrence does not carry the rule: show the series'.
    final master = event?.seriesId == null
        ? null
        : await repository.findById(event!.seriesId!);
    if (!mounted) return;
    if (event == null) {
      setState(() => _notFound = true);
      return;
    }
    _original = event;
    final draft = EventDraft.fromEvent(event);
    if (master != null) {
      draft
        ..rrule = master.rrule
        ..holidayRule = master.holidayRule;
    }
    _setDraft(draft);
  }

  void _setDraft(EventDraft draft) {
    setState(() => _draft = draft);
    _title.text = draft.title;
    _location.text = draft.location ?? '';
    _videoLink.text = draft.videoLink ?? '';
    _description.text = draft.description;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _videoLink.dispose();
    _description.dispose();
    super.dispose();
  }

  void _readFields() {
    _draft!
      ..title = _title.text
      ..location = _location.text
      ..videoLink = _videoLink.text
      ..description = _description.text;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final draft = _draft;
    if (draft == null) return;
    _readFields();
    final error = draft.validate();
    setState(() {
      _titleError = error == DraftError.emptyTitle
          ? l10n.errorEmptyTitle
          : null;
      _timeError = switch (error) {
        DraftError.endBeforeStart => l10n.errorEndBeforeStart,
        DraftError.unknownTimeZone => l10n.errorUnknownTimeZone,
        _ => null,
      };
    });
    if (error != null) return;
    final original = _original;
    final repository = ref.read(eventRepositoryProvider);
    if (original == null) {
      final created = await createFromDraft(ref, draft);
      final attachments = ref.read(attachmentRepositoryProvider);
      for (final f in _pendingAttachments) {
        await attachments.add(created.id, f.name, f.bytes);
      }
    } else if (original.seriesId != null) {
      final scope = await askSeriesScope(context, deleting: false);
      if (scope == null) return;
      await repository.saveOccurrence(draft.applyTo(original), scope);
    } else {
      await repository.update(draft.applyTo(original));
    }
    if (mounted) context.pop();
  }

  Future<void> _pickDate({required bool start}) async {
    final draft = _draft!;
    final current = start ? draft.startDay : draft.endDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.toLocalMidnight(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked == null) return;
    final day = Day.fromDateTime(picked);
    setState(() {
      if (start) {
        // Keep the duration when the start moves.
        final shift = day.differenceInDays(draft.startDay);
        draft
          ..startDay = day
          ..endDay = draft.endDay.addDays(shift);
      } else {
        draft.endDay = day;
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final draft = _draft!;
    final minutes = start ? draft.startMinute : draft.endMinute;
    final picked = await pickTime(
      context,
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    final value = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        final duration =
            draft.endDay.differenceInDays(draft.startDay) * 24 * 60 +
            draft.endMinute -
            draft.startMinute;
        final end = value + duration;
        draft
          ..startMinute = value
          ..endDay = draft.startDay.addDays(end ~/ (24 * 60))
          ..endMinute = end % (24 * 60);
      } else {
        draft.endMinute = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_notFound) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.eventNotFound)),
      );
    }
    final draft = _draft;
    if (draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final isNew = _original == null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.escape): () => context.pop(),
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
          title: Text(isNew ? l10n.newEvent : l10n.editEvent),
          actions: [
            if (!isNew)
              PopupMenuButton<String>(
                onSelected: (action) async {
                  final original = _original!;
                  if (action == 'duplicate') {
                    final copy = await duplicateEvent(context, ref, original);
                    if (context.mounted) {
                      context.pushReplacement('/event/${copy.id}');
                    }
                  } else if (action == 'delete') {
                    final deleted = await deleteEventWithUndo(
                      context,
                      ref,
                      original,
                    );
                    if (deleted && context.mounted) context.pop();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Text(l10n.duplicate),
                  ),
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FilledButton(onPressed: _save, child: Text(l10n.save)),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _title,
                  autofocus: isNew,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: InputDecoration(
                    labelText: l10n.fieldTitle,
                    errorText: _titleError,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.wb_sunny_outlined),
                  title: Text(l10n.allDay),
                  value: draft.allDay,
                  onChanged: (v) => setState(() => draft.allDay = v),
                ),
                _DateTimeRow(
                  key: const ValueKey('start'),
                  label: l10n.fieldStart,
                  day: draft.startDay,
                  minute: draft.allDay ? null : draft.startMinute,
                  onPickDate: () => _pickDate(start: true),
                  onPickTime: () => _pickTime(start: true),
                ),
                _DateTimeRow(
                  key: const ValueKey('end'),
                  label: l10n.fieldEnd,
                  day: draft.endDay,
                  minute: draft.allDay ? null : draft.endMinute,
                  onPickDate: () => _pickDate(start: false),
                  onPickTime: () => _pickTime(start: false),
                ),
                if (_timeError != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      _timeError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (!draft.allDay)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.public),
                    title: Text(l10n.fieldTimeZone),
                    subtitle: Text(draft.timeZone),
                    onTap: () async {
                      final zone = await showTimeZonePicker(
                        context,
                        draft.timeZone,
                      );
                      if (zone != null) setState(() => draft.timeZone = zone);
                    },
                  ),
                _RecurrenceTile(
                  draft: draft,
                  // An occurrence's date is not the series' start.
                  editableStart: _original?.seriesId == null,
                  onChanged: () => setState(() {}),
                ),
                RemindersEditor(draft: draft, onChanged: () => setState(() {})),
                _OverlapWarning(draft: draft, ignoreId: _original?.id),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.label_outline),
                  title: Text(l10n.fieldCategory),
                  trailing: DropdownButton<String?>(
                    value: categories.any((c) => c.id == draft.categoryId)
                        ? draft.categoryId
                        : null,
                    onChanged: (v) => setState(() => draft.categoryId = v),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.noCategory),
                      ),
                      for (final c in categories)
                        DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(c.color),
                              ),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.fieldColor),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ColorPalette(
                      selected: draft.color,
                      allowNone: true,
                      noneLabel: l10n.colorFromCategory,
                      onSelected: (c) => setState(() => draft.color = c),
                    ),
                  ),
                ),
                const Divider(),
                TextField(
                  controller: _location,
                  // Another place: the position found before is wrong.
                  onChanged: (_) {
                    if (draft.placePoint != null) {
                      setState(() => draft.placePoint = null);
                    }
                  },
                  decoration: InputDecoration(
                    icon: const Icon(Icons.place_outlined),
                    labelText: l10n.fieldLocation,
                    helperText: draft.placePoint == null
                        ? null
                        : l10n.placeFound,
                    suffixIcon: IconButton(
                      tooltip: l10n.placeSearch,
                      icon: Icon(
                        draft.placePoint == null
                            ? Icons.travel_explore
                            : Icons.where_to_vote,
                      ),
                      onPressed: () async {
                        final place = await showPlaceSearch(
                          context,
                          initial: _location.text,
                        );
                        if (place == null) return;
                        setState(() {
                          if (_location.text.trim().isEmpty) {
                            _location.text = place.label;
                          }
                          draft.placePoint = place.point;
                        });
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: ValueListenableBuilder(
                    valueListenable: _location,
                    builder: (context, value, _) => NavigationButton(
                      point: draft.placePoint,
                      address: value.text,
                      label: _title.text,
                    ),
                  ),
                ),
                RouteSection(
                  eventId: _original == null
                      ? null
                      : _original!.seriesId ?? _original!.id,
                  destination: draft.placePoint,
                ),
                TextField(
                  controller: _videoLink,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    icon: const Icon(Icons.videocam_outlined),
                    labelText: l10n.fieldVideoLink,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.event_busy_outlined),
                    const SizedBox(width: 16),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: true, label: Text(l10n.busy)),
                        ButtonSegment(value: false, label: Text(l10n.free)),
                      ],
                      selected: {draft.busy},
                      onSelectionChanged: (s) =>
                          setState(() => draft.busy = s.single),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    icon: const Icon(Icons.notes),
                    labelText: l10n.fieldDescription,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                AttachmentsEditor(
                  eventId: _original == null
                      ? null
                      : _original!.seriesId ?? _original!.id,
                  pending: _pendingAttachments,
                  onPendingChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    super.key,
    required this.label,
    required this.day,
    required this.minute,
    required this.onPickDate,
    required this.onPickTime,
  });

  final String label;
  final Day day;
  final int? minute;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label)),
          Expanded(
            child: OutlinedButton(
              onPressed: onPickDate,
              child: Text(formatDayShort(context, day)),
            ),
          ),
          if (minute != null) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onPickTime,
              child: Text(formatMinutes(minute!)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lists busy events overlapping the edited times.
class _OverlapWarning extends ConsumerWidget {
  const _OverlapWarning({required this.draft, required this.ignoreId});

  final EventDraft draft;
  final String? ignoreId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (draft.allDay ||
        !draft.busy ||
        draft.validate() == DraftError.endBeforeStart) {
      return const SizedBox();
    }
    final times = draft.resolve();
    final range = (
      first: draft.startDay.addDays(-1),
      last: draft.endDay.addDays(1),
    );
    final byDay = ref.watch(eventsByDayProvider(range)).value ?? const {};
    final probe = CalendarEvent(
      id: '\u0000draft',
      title: '',
      start: times.start,
      end: times.end,
      timeZone: draft.timeZone,
      createdAt: times.start,
      updatedAt: times.start,
    );
    final others = {
      for (final list in byDay.values)
        for (final e in list)
          if (e.id != ignoreId) e.id: e,
    };
    final conflicts = <CalendarEvent>[
      for (final e in others.values)
        if (overlappingEventIds([probe, e]).contains(probe.id)) e,
    ];
    if (conflicts.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.warning_amber_rounded,
          color: scheme.onTertiaryContainer,
        ),
        title: Text(
          AppLocalizations.of(context)
              .overlapsWith(conflicts.map((e) => e.title).join(', ')),
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
      ),
    );
  }
}

class _RecurrenceTile extends StatelessWidget {
  const _RecurrenceTile({
    required this.draft,
    required this.editableStart,
    required this.onChanged,
  });

  final EventDraft draft;
  final bool editableStart;
  final VoidCallback onChanged;

  Future<Day?> _pickDay(BuildContext context, Day initial, Day first) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (initial.isBefore(first) ? first : initial)
          .toLocalMidnight(),
      firstDate: first.toLocalMidnight(),
      lastDate: DateTime(2200),
    );
    return picked == null ? null : Day.fromDateTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    RecurrenceRule? rule;
    try {
      rule = draft.rrule == null ? null : RecurrenceRule.parse(draft.rrule!);
    } on FormatException {
      rule = null;
    }
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.repeat),
          title: Text(l10n.fieldRecurrence),
          subtitle: Text(
            rule == null
                ? l10n.recurrenceNone
                : describeRule(rule, draft.startDay, localeOf(context)),
          ),
          onTap: () async {
            final choice = await showRecurrencePicker(
              context,
              start: draft.startDay,
              current: rule,
            );
            if (choice == null) return;
            var picked = choice.rule;
            // A preset keeps the end date chosen below.
            if (picked != null && !picked.isBounded && rule?.until != null) {
              picked = picked.copyWith(until: () => rule!.until);
            }
            draft.rrule = picked?.toString();
            onChanged();
          },
        ),
        if (rule != null && editableStart)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.first_page),
            title: Text(l10n.recurrenceStartDate),
            trailing: TextButton(
              onPressed: () async {
                final day = await _pickDay(
                  context,
                  draft.startDay,
                  Day(1900, 1, 1),
                );
                if (day == null) return;
                // The event moves with the start of the series.
                final shift = day.differenceInDays(draft.startDay);
                draft
                  ..startDay = day
                  ..endDay = draft.endDay.addDays(shift);
                if (rule!.until != null && rule.until!.isBefore(day)) {
                  draft.rrule = rule.copyWith(until: () => day).toString();
                }
                onChanged();
              },
              child: Text(formatDayShort(context, draft.startDay)),
            ),
          ),
        if (rule != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.last_page),
            title: Text(l10n.recurrenceEndDate),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: const ValueKey('recurrence-end'),
                  onPressed: () async {
                    final day = await _pickDay(
                      context,
                      rule!.until ?? draft.startDay.addMonths(1),
                      draft.startDay,
                    );
                    if (day == null) return;
                    draft.rrule = rule!
                        .copyWith(count: () => null, until: () => day)
                        .toString();
                    onChanged();
                  },
                  child: Text(
                    rule.until != null
                        ? formatDayShort(context, rule.until!)
                        : rule.count != null
                        ? l10n.recurrenceEndCount(rule.count!)
                        : l10n.recurrenceNever,
                  ),
                ),
                if (rule.isBounded)
                  IconButton(
                    tooltip: l10n.recurrenceNoEnd,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      draft.rrule = rule!
                          .copyWith(count: () => null, until: () => null)
                          .toString();
                      onChanged();
                    },
                  ),
              ],
            ),
          ),
        if (rule != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.fieldHolidayRule),
            trailing: DropdownButton<HolidayRule>(
              value: draft.holidayRule,
              onChanged: (v) {
                draft.holidayRule = v!;
                onChanged();
              },
              items: [
                for (final (value, label) in [
                  (HolidayRule.none, l10n.holidayRuleNone),
                  (HolidayRule.skip, l10n.holidayRuleSkip),
                  (HolidayRule.nextWorkingDay, l10n.holidayRuleNext),
                  (HolidayRule.previousWorkingDay, l10n.holidayRulePrevious),
                ])
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
            ),
          ),
      ],
    );
  }
}
