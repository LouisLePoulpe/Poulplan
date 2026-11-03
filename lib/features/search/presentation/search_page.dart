import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../data/providers.dart';
import '../../../domain/calendar/day.dart';
import '../../../domain/entities/calendar_event.dart';
import '../../../domain/recurrence/recurrence_rule.dart';
import '../../../domain/search/search_query.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../calendar/presentation/event_actions.dart';
import '../../calendar/presentation/widgets/event_style.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../event_editor/presentation/recurrence_text.dart';

enum _Period { all, upcoming, past, custom }

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _text = TextEditingController();
  Timer? _debounce;
  SearchQuery _query = SearchQuery();
  _Period _period = _Period.all;
  Future<List<CalendarEvent>>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _apply(SearchQuery query) {
    setState(() {
      _query = query;
      _results = query.isEmpty
          ? null
          : ref.read(eventRepositoryProvider).search(query);
    });
  }

  void _onText(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _apply(_query.copyWith(text: text)),
    );
  }

  Future<void> _setPeriod(_Period period) async {
    final today = ref.read(todayProvider);
    Day? from;
    Day? to;
    switch (period) {
      case _Period.all:
        break;
      case _Period.upcoming:
        from = today;
      case _Period.past:
        to = today.addDays(-1);
      case _Period.custom:
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
          initialDateRange: DateTimeRange(
            start: today.toLocalMidnight(),
            end: today.addMonths(1).toLocalMidnight(),
          ),
        );
        if (range == null) return;
        from = Day.fromDateTime(range.start);
        to = Day.fromDateTime(range.end);
    }
    _period = period;
    _apply(_query.copyWith(from: () => from, to: () => to));
  }

  Future<void> _saveFilter() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: _query.text),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(savedFilterRepositoryProvider).save(name.trim(), _query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final saved = ref.watch(savedFiltersProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _text,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: _onText,
          onSubmitted: (t) => _apply(_query.copyWith(text: t)),
        ),
        actions: [
          IconButton(
            tooltip: l10n.saveFilter,
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _query.isEmpty ? null : _saveFilter,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (saved.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final f in saved)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InputChip(
                        avatar: const Icon(Icons.bookmark_outline, size: 18),
                        label: Text(f.name),
                        onPressed: () {
                          _text.text = f.query.text;
                          _period = f.query.from == null && f.query.to == null
                              ? _Period.all
                              : _Period.custom;
                          _apply(f.query);
                        },
                        onDeleted: () => ref
                            .read(savedFilterRepositoryProvider)
                            .delete(f.id),
                        deleteButtonTooltipMessage: l10n.delete,
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (period, label) in [
                  (_Period.all, l10n.periodAll),
                  (_Period.upcoming, l10n.periodUpcoming),
                  (_Period.past, l10n.periodPast),
                  (_Period.custom, l10n.periodCustom),
                ])
                  ChoiceChip(
                    label: Text(
                      period == _Period.custom &&
                              _period == _Period.custom &&
                              _query.from != null &&
                              _query.to != null
                          ? '${formatDayShort(context, _query.from!)} – '
                                '${formatDayShort(context, _query.to!)}'
                          : label,
                    ),
                    selected: _period == period,
                    onSelected: (_) => _setPeriod(period),
                  ),
                const SizedBox(width: 8),
                for (final c in categories)
                  FilterChip(
                    avatar: CircleAvatar(backgroundColor: Color(c.color)),
                    label: Text(c.name),
                    selected: _query.categoryIds.contains(c.id),
                    onSelected: (on) => _apply(
                      _query.copyWith(
                        categoryIds: on
                            ? {..._query.categoryIds, c.id}
                            : ({..._query.categoryIds}..remove(c.id)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _results == null
                ? Center(child: Text(l10n.searchPrompt))
                : FutureBuilder<List<CalendarEvent>>(
                    future: _results,
                    builder: (context, snapshot) {
                      final results = snapshot.data;
                      if (results == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (results.isEmpty) {
                        return Center(child: Text(l10n.searchNoResults));
                      }
                      return ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) =>
                            _ResultTile(event: results[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends ConsumerWidget {
  const _ResultTile({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toLocal = ref.watch(localTimeProvider);
    final start = toLocal(event.start);
    final day = Day.fromDateTime(event.allDay ? event.start : start);
    var when = formatDayShort(context, day);
    if (!event.allDay) when += ' · ${formatClock(start)}';
    if (event.rrule != null) {
      try {
        when = describeRule(
          RecurrenceRule.parse(event.rrule!),
          day,
          localeOf(context),
        );
      } on FormatException {
        // Keep the date.
      }
    }
    return ListTile(
      leading: Container(
        width: 6,
        height: 36,
        decoration: BoxDecoration(
          color: eventColor(ref, context, event),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Text(event.title),
      subtitle: Text([when, ?event.location].join(' · ')),
      onTap: () => openEvent(context, event),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.saveFilter),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.fieldName),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
