import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../data/providers.dart';
import '../../../domain/entities/calendar_event.dart';
import '../../../l10n/generated/app_localizations.dart';

void openEvent(BuildContext context, CalendarEvent event) =>
    context.push(Routes.event(event.id));

Future<void> deleteEventWithUndo(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(eventRepositoryProvider);
  await repository.delete(event.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.eventDeleted(event.title)),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => repository.restore(event.id),
        ),
      ),
    );
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

/// Persists an event moved by drag and drop.
Future<void> saveMovedEvent(WidgetRef ref, CalendarEvent moved) =>
    ref.read(eventRepositoryProvider).update(moved);

/// Right-click / long-press menu on an event.
Future<void> showEventMenu(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
  Offset globalPosition,
) async {
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
