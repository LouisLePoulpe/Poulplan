import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/event_repository.dart';
import '../../../domain/entities/calendar_event.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Opens what was tapped: the editor for events, the birthdays list for
/// birthdays; holidays only show their name.
void openEvent(BuildContext context, CalendarEvent event) {
  switch (event.kind) {
    case EventKind.event:
      context.push(Routes.event(event.id));
    case EventKind.birthday:
      context.push(Routes.birthdays);
    case EventKind.holiday || EventKind.schoolHoliday:
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(event.title)));
  }
}

/// Asks which occurrences of a series an action applies to. Null when the
/// user cancels.
Future<SeriesScope?> askSeriesScope(
  BuildContext context, {
  required bool deleting,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<SeriesScope>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(deleting ? l10n.scopeDeleteTitle : l10n.scopeEditTitle),
      children: [
        for (final (scope, label) in [
          (SeriesScope.thisOccurrence, l10n.scopeThis),
          (SeriesScope.thisAndFollowing, l10n.scopeFollowing),
          (SeriesScope.all, l10n.scopeAll),
        ])
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(scope),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(label),
            ),
          ),
      ],
    ),
  );
}

void _showUndo(
  BuildContext context,
  ScaffoldMessengerState messenger,
  String message,
  VoidCallback? undo,
) {
  final l10n = AppLocalizations.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: undo == null
            ? null
            : SnackBarAction(label: l10n.undo, onPressed: undo),
      ),
    );
}

/// Deletes [event], asking for the scope when it belongs to a series.
/// Returns false when cancelled.
Future<bool> deleteEventWithUndo(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(eventRepositoryProvider);
  final message = l10n.eventDeleted(event.title);
  if (event.seriesId == null) {
    await repository.delete(event.id);
    if (context.mounted) {
      _showUndo(
        context,
        messenger,
        message,
        () => repository.restore(event.id),
      );
    }
    return true;
  }
  final scope = await askSeriesScope(context, deleting: true);
  if (scope == null) return false;
  final undoId = await repository.deleteOccurrence(event, scope);
  if (!context.mounted) return true;
  _showUndo(
    context,
    messenger,
    message,
    undoId == null
        ? null
        : scope == SeriesScope.thisOccurrence
        ? () => repository.uncancel(undoId)
        : () => repository.restore(undoId),
  );
  return true;
}

Future<CalendarEvent> duplicateEvent(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final copy = await ref.read(eventRepositoryProvider).duplicate(event);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.eventDuplicated)));
  return copy;
}

/// Persists an event moved by drag and drop (asking for the scope when it
/// belongs to a series).
Future<void> saveMovedEvent(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent moved,
) async {
  final repository = ref.read(eventRepositoryProvider);
  if (moved.seriesId == null) {
    await repository.update(moved);
    return;
  }
  final scope = await askSeriesScope(context, deleting: false);
  if (scope != null) await repository.saveOccurrence(moved, scope);
}

/// Right-click / long-press menu on an event.
Future<void> showEventMenu(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
  Offset globalPosition,
) async {
  if (event.kind != EventKind.event) return;
  final l10n = AppLocalizations.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
      PopupMenuItem(value: 'duplicate', child: Text(l10n.duplicate)),
      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
    ],
  );
  if (!context.mounted) return;
  switch (action) {
    case 'edit':
      openEvent(context, event);
    case 'duplicate':
      await duplicateEvent(context, ref, event);
    case 'delete':
      await deleteEventWithUndo(context, ref, event);
  }
}
