import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/formatters.dart';
import '../../../core/platform/file_exchange.dart';
import '../../../data/backup/backup_service.dart';
import '../../../data/backup/backup_store.dart';
import '../../../data/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../sync/providers/sync_controller.dart';
import '../backup_manager.dart';

/// « 1,2 Mo », « 830 ko ».
String formatBytes(int bytes, String locale) {
  final format = NumberFormat('#,##0.#', locale);
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) return '${format.format(bytes / 1024)} ko';
  if (bytes < 1024 * 1024 * 1024) {
    return '${format.format(bytes / (1024 * 1024))} Mo';
  }
  return '${format.format(bytes / (1024 * 1024 * 1024))} Go';
}

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  List<StoredBackup> _local = const [];
  List<StoredBackup>? _cloud;
  DateTime? _lastLocal;
  bool _busy = false;

  BackupManager get _manager => ref.read(backupManagerProvider);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final local = await (await _manager.localStore()).list();
    final last = await _manager.lastLocal();
    List<StoredBackup>? cloud;
    try {
      cloud = await _manager.cloudStore()?.list();
    } catch (_) {
      cloud = null; // offline: the cloud list is just not shown
    }
    if (!mounted) return;
    setState(() {
      _local = local;
      _cloud = cloud;
      _lastLocal = last;
    });
  }

  void _show(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// Runs [action] with the progress bar, reporting errors.
  Future<void> _run(Future<String?> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final message = await action();
      if (message != null) _show(message);
    } on BackupFormatException {
      _show(l10n.backupInvalid);
    } catch (e) {
      _show(l10n.operationFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  String _date(DateTime date) =>
      DateFormat("d MMMM y 'à' HH:mm", localeOf(context)).format(date);

  Future<String?> _restore(List<int> bytes) async {
    final l10n = AppLocalizations.of(context);
    final info = await _manager.inspect(bytes);
    if (!mounted) return null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupRestoreConfirmTitle),
        content: Text(
          l10n.backupRestoreConfirmBody(
            _date(info.createdAt.toLocal()),
            info.device,
            info.events,
            info.birthdays,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.backupRestore),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    final result = await _manager.restore(bytes);
    return l10n.backupRestored(result.records);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final repository = ref.read(settingsRepositoryProvider);
    final signedIn = ref.watch(syncControllerProvider).signedIn;
    final locale = localeOf(context);
    final theme = Theme.of(context);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    Widget backupTile(StoredBackup b, {required bool cloud}) => ListTile(
      leading: Icon(
        cloud ? Icons.cloud_done_outlined : Icons.inventory_2_outlined,
      ),
      title: Text(_date(b.date)),
      subtitle: b.size == null ? null : Text(formatBytes(b.size!, locale)),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => _run(() async {
          switch (action) {
            case 'restore':
              final bytes = cloud
                  ? await _manager.cloudStore()!.download(b.name)
                  : await (await _manager.localStore()).read(b.name);
              return _restore(bytes);
            case 'export':
              final bytes = cloud
                  ? await _manager.cloudStore()!.download(b.name)
                  : await (await _manager.localStore()).read(b.name);
              final saved = await FileExchange.save(
                name: b.name,
                mime: 'application/zip',
                extension: 'zip',
                bytes: bytes,
              );
              return saved ? l10n.fileSaved : null;
            case 'delete':
              await (await _manager.localStore()).delete(b.name);
              return null;
          }
          return null;
        }),
        itemBuilder: (context) => [
          PopupMenuItem(value: 'restore', child: Text(l10n.backupRestore)),
          PopupMenuItem(value: 'export', child: Text(l10n.backupExport)),
          if (!cloud) PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupsTitle),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.backupAuto),
            subtitle: Text(l10n.backupAutoSubtitle(BackupManager.keepLocal)),
            value: settings.autoBackup,
            onChanged: repository.setAutoBackup,
          ),
          if (signedIn)
            SwitchListTile(
              title: Text(l10n.backupCloudAuto),
              subtitle: Text(
                l10n.backupCloudAutoSubtitle(BackupManager.keepCloud),
              ),
              value: settings.cloudBackup,
              onChanged: settings.autoBackup ? repository.setCloudBackup : null,
            ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(
              _lastLocal == null
                  ? l10n.backupNever
                  : l10n.backupLast(_date(_lastLocal!)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.backupNow),
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await _manager.backupLocally();
                          return l10n.backupDone;
                        }),
                ),
                if (signedIn)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(l10n.backupNowCloud),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _manager.backupToCloud();
                            return l10n.backupDone;
                          }),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: Text(l10n.backupRestoreFile),
            enabled: !_busy,
            onTap: () => _run(() async {
              final file = await FileExchange.pick(
                label: 'Poulplan',
                extensions: const ['zip'],
                mimeTypes: const [
                  'application/zip',
                  'application/octet-stream',
                ],
              );
              return file == null ? null : _restore(file.bytes);
            }),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(l10n.backupExport),
            enabled: !_busy,
            onTap: () => _run(() async {
              final saved = await FileExchange.save(
                name: backupFileName(DateTime.now()),
                mime: 'application/zip',
                extension: 'zip',
                bytes: await _manager.createBytes(),
              );
              return saved ? l10n.fileSaved : null;
            }),
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: Text(l10n.exportIcs),
            enabled: !_busy,
            onTap: () => _run(() async {
              final saved = await FileExchange.save(
                name: 'poulplan.ics',
                mime: 'text/calendar',
                extension: 'ics',
                bytes: utf8.encode(await _manager.exportIcs()),
              );
              return saved ? l10n.fileSaved : null;
            }),
          ),
          section(l10n.backupLocalList),
          if (_local.isEmpty) ListTile(title: Text(l10n.backupNone)),
          for (final b in _local) backupTile(b, cloud: false),
          if (_cloud != null) ...[
            section(l10n.backupCloudList),
            if (_cloud!.isEmpty) ListTile(title: Text(l10n.backupNone)),
            for (final b in _cloud!) backupTile(b, cloud: true),
          ],
        ],
      ),
    );
  }
}
