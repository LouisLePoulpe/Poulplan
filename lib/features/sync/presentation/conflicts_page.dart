import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../data/db/app_database.dart';
import '../../../domain/calendar/day.dart';
import '../../../domain/sync/sync_record.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/sync_controller.dart';

class ConflictsPage extends ConsumerWidget {
  const ConflictsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final conflicts = ref.watch(syncConflictsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.conflictsTitle)),
      body: conflicts.isEmpty
          ? Center(child: Text(l10n.conflictsNone))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(l10n.conflictsExplanation),
                const SizedBox(height: 12),
                for (final c in conflicts) _ConflictCard(conflict: c),
              ],
            ),
    );
  }
}

class _ConflictCard extends ConsumerWidget {
  const _ConflictCard({required this.conflict});

  final SyncConflictRow conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final resolver = ref.read(conflictResolverProvider);
    final isDeletion = conflict.field == deletedField;
    String show(String json) =>
        _describe(context, conflict.field, jsonDecode(json), l10n);

    Future<void> choose({required bool keepLocal}) async {
      await resolver.resolve(conflict, keepLocal: keepLocal);
      await ref.read(syncControllerProvider.notifier).syncNow();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isDeletion
                  ? l10n.conflictDeletion
                  : l10n.conflictField(_fieldLabel(conflict.field, l10n)),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => choose(keepLocal: true),
                    child: Text(
                      '${l10n.conflictThisDevice}\n${show(conflict.localValue)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => choose(keepLocal: false),
                    child: Text(
                      '${l10n.conflictOtherDevice}\n'
                      '${show(conflict.remoteValue)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _fieldLabel(String field, AppLocalizations l10n) => switch (field) {
  'title' => l10n.fieldTitle,
  'description' => l10n.fieldDescription,
  'location' => l10n.fieldLocation,
  'videoLink' => l10n.fieldVideoLink,
  'startUtc' => l10n.fieldStart,
  'endUtc' => l10n.fieldEnd,
  'timeZone' => l10n.fieldTimeZone,
  'categoryId' => l10n.fieldCategory,
  'color' => l10n.fieldColor,
  'rrule' => l10n.fieldRecurrence,
  'name' => l10n.fieldName,
  _ => field,
};

String _describe(
  BuildContext context,
  String field,
  Object? value,
  AppLocalizations l10n,
) {
  if (field == deletedField) {
    return value == true ? l10n.conflictDeleted : l10n.conflictKept;
  }
  if (value == null || value == '') return '—';
  if ((field == 'startUtc' || field == 'endUtc') && value is int) {
    final local = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    return '${formatDayShort(context, Day.fromDateTime(local))} '
        '${formatClock(local)}';
  }
  return '$value';
}
