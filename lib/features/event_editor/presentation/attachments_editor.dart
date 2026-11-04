
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/platform/file_exchange.dart';
import '../../../data/attachments/attachment_transfer.dart';
import '../../../data/providers.dart';
import '../../../domain/entities/attachment.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../backup/presentation/backup_page.dart' show formatBytes;
import '../../sync/providers/sync_controller.dart';

/// A file chosen for an event that is not saved yet.
typedef PendingAttachment = ({String name, Uint8List bytes});

/// Largest attachment (Supabase Storage accepts 50 MB by default).
const maxAttachmentMegabytes = 25;

IconData _icon(String mimeType) => switch (mimeType.split('/').first) {
  'image' => Icons.image_outlined,
  'audio' => Icons.audiotrack_outlined,
  'video' => Icons.movie_outlined,
  'text' => Icons.article_outlined,
  _ when mimeType == 'application/pdf' => Icons.picture_as_pdf_outlined,
  _ => Icons.attach_file,
};

/// Attachments of the event [eventId] (series master for a series), or the
/// [pending] files of a new event, saved with it.
class AttachmentsEditor extends ConsumerWidget {
  const AttachmentsEditor({
    super.key,
    required this.eventId,
    required this.pending,
    required this.onPendingChanged,
  });

  final String? eventId;
  final List<PendingAttachment> pending;
  final VoidCallback onPendingChanged;

  void _show(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final file = await FileExchange.pick(
      label: l10n.attachments,
      extensions: const [],
      mimeTypes: const ['*/*'],
    );
    if (file == null || !context.mounted) return;
    if (file.bytes.length > maxAttachmentMegabytes * 1024 * 1024) {
      _show(context, l10n.attachmentTooBig(maxAttachmentMegabytes));
      return;
    }
    if (eventId == null) {
      pending.add(file);
      onPendingChanged();
    } else {
      await ref
          .read(attachmentRepositoryProvider)
          .add(eventId!, file.name, file.bytes);
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Attachment a) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(attachmentRepositoryProvider);
    final transfer = ref.read(attachmentTransferProvider);
    try {
      final file = a.stored && repository.file(a).existsSync()
          ? repository.file(a)
          : await (transfer ?? (throw const AttachmentUnavailableException()))
                .fetch(a);
      await FileExchange.open(file.path, a.mimeType);
    } on PlatformException catch (e) {
      if (context.mounted) {
        _show(
          context,
          e.code == 'NO_APP'
              ? l10n.attachmentNoApp
              : l10n.operationFailed(e.message ?? e.code),
        );
      }
    } catch (_) {
      if (context.mounted) _show(context, l10n.attachmentUnavailable);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = localeOf(context);
    final attachments = eventId == null
        ? const <Attachment>[]
        : ref.watch(attachmentsProvider(eventId!)).value ?? const [];
    final signedIn = ref.watch(syncControllerProvider).signedIn;

    String status(Attachment a) => [
      formatBytes(a.size, locale),
      if (a.keepOffline)
        l10n.attachmentKept
      else if (a.stored)
        l10n.attachmentOnDevice
      else
        l10n.attachmentInCloud,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file),
          title: Text(l10n.attachments),
          trailing: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.attachmentAdd),
            onPressed: () => _add(context, ref),
          ),
        ),
        for (final a in attachments)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 40),
            leading: Icon(_icon(a.mimeType)),
            title: Text(a.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(status(a)),
            onTap: () => _open(context, ref, a),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                final repository = ref.read(attachmentRepositoryProvider);
                if (action == 'keep') {
                  await repository.setKeepOffline(a.id, !a.keepOffline);
                  await ref.read(attachmentTransferProvider)?.run();
                } else if (action == 'delete') {
                  await repository.delete(a.id);
                }
              },
              itemBuilder: (context) => [
                if (signedIn)
                  CheckedPopupMenuItem(
                    value: 'keep',
                    checked: a.keepOffline,
                    child: Text(l10n.attachmentKeepOffline),
                  ),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
          ),
        for (final (i, f) in pending.indexed)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 40),
            leading: Icon(_icon(guessMimeType(f.name))),
            title: Text(f.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${formatBytes(f.bytes.length, locale)} · '
              '${l10n.attachmentPending}',
            ),
            trailing: IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.close),
              onPressed: () {
                pending.removeAt(i);
                onPendingChanged();
              },
            ),
          ),
      ],
    );
  }
}
