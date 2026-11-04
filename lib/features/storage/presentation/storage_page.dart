import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../data/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../backup/presentation/backup_page.dart' show formatBytes;
import '../storage_report.dart';

class StoragePage extends ConsumerWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = localeOf(context);
    final report = ref.watch(storageReportProvider);
    String size(int bytes) => formatBytes(bytes, locale);

    Future<void> clean(Future<int> Function() action) async {
      final freed = await action();
      ref.invalidate(storageReportProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.storageFreed(size(freed)))));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.storageTitle)),
      body: switch (report) {
        AsyncData(:final value) => ListView(
          children: [
            if (value.lowSpace)
              MaterialBanner(
                leading: const Icon(Icons.warning_amber),
                content: Text(l10n.storageLow(size(value.reclaimableBytes))),
                actions: const [SizedBox.shrink()],
              ),
            for (final (icon, label, bytes) in [
              (Icons.event, l10n.storageDatabase, value.databaseBytes),
              (
                Icons.attach_file,
                l10n.storageAttachments,
                value.attachmentBytes,
              ),
              (
                Icons.inventory_2_outlined,
                l10n.storageBackups,
                value.backupBytes,
              ),
              (Icons.functions, l10n.storageTotal, value.totalBytes),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: Text(size(bytes)),
              ),
            if (value.freeBytes != null)
              ListTile(
                leading: const Icon(Icons.sd_storage_outlined),
                title: Text(l10n.storageFree),
                trailing: Text(size(value.freeBytes!)),
              ),
            const Divider(),
            if (value.reclaimableBytes == 0)
              ListTile(title: Text(l10n.storageNothing)),
            if (value.freeableAttachmentBytes > 0)
              ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(l10n.storageFreeAttachments),
                subtitle: Text(
                  l10n.storageFreeAttachmentsSubtitle(
                    size(value.freeableAttachmentBytes),
                  ),
                ),
                onTap: () => clean(
                  ref.read(attachmentRepositoryProvider).freeLocalCopies,
                ),
              ),
            if (value.oldBackupBytes > 0)
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text(l10n.storageDeleteOldBackups),
                subtitle: Text(
                  l10n.storageDeleteOldBackupsSubtitle(
                    size(value.oldBackupBytes),
                  ),
                ),
                onTap: () => clean(() => deleteOldBackups(ref)),
              ),
          ],
        ),
        AsyncError(:final error) => Center(
          child: Text(l10n.operationFailed('$error')),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
