import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/desktop_integration.dart';
import '../../../data/notifications/notification_service.dart';
import '../../../data/providers.dart';
import '../../../domain/reminders/reminders.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../reminders/reminder_scheduler.dart';

final _permissionProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationServiceProvider).permissionGranted(),
);

class RemindersSettings extends ConsumerStatefulWidget {
  const RemindersSettings({super.key});

  @override
  ConsumerState<RemindersSettings> createState() => _RemindersSettingsState();
}

class _RemindersSettingsState extends ConsumerState<RemindersSettings> {
  late bool _autostart = DesktopIntegration.autostartEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final repository = ref.read(settingsRepositoryProvider);
    final permission = ref.watch(_permissionProvider).value;
    final android = NotificationService.systemScheduling;

    return Column(
      children: [
        if (android)
          ListTile(
            leading: Icon(
              permission == true
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
            ),
            title: Text(
              permission == true
                  ? l10n.notificationsAllowed
                  : l10n.notificationsDenied,
            ),
            trailing: permission == true
                ? null
                : FilledButton(
                    onPressed: () async {
                      await ref
                          .read(notificationServiceProvider)
                          .requestPermission();
                      ref.invalidate(_permissionProvider);
                    },
                    child: Text(l10n.notificationsAllow),
                  ),
          ),
        ListTile(
          leading: const Icon(Icons.alarm),
          title: Text(l10n.settingsDefaultReminder),
          subtitle: Text(l10n.settingsDefaultReminderSubtitle),
          trailing: DropdownButton<int?>(
            value: settings.defaultReminder,
            onChanged: repository.setDefaultReminder,
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.noReminder)),
              for (final minutes in const [0, 5, 10, 15, 30, 60])
                DropdownMenuItem(
                  value: minutes,
                  child: Text(describeReminder(minutes, allDay: false)),
                ),
            ],
          ),
        ),
        if (NotificationService.supported)
          ListTile(
            leading: const Icon(Icons.notification_add_outlined),
            title: Text(l10n.notificationsTest),
            subtitle: Text(
              android
                  ? l10n.notificationsTestSubtitleAndroid
                  : l10n.notificationsTestSubtitle,
            ),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(notificationServiceProvider);
              await service.init();
              if (android) await service.requestPermission();
              await ref.read(reminderSchedulerProvider).sendTest();
              ref.invalidate(_permissionProvider);
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.notificationsTestSent)),
              );
            },
          ),
        if (DesktopIntegration.isLinux) ...[
          SwitchListTile(
            secondary: const Icon(Icons.layers_outlined),
            title: Text(l10n.settingsRunInBackground),
            subtitle: Text(l10n.settingsRunInBackgroundSubtitle),
            value: settings.runInBackground,
            onChanged: (v) async {
              await repository.setRunInBackground(v);
              await DesktopIntegration.setHideOnClose(v);
            },
          ),
          if (DesktopIntegration.canManageAutostart)
            SwitchListTile(
              secondary: const Icon(Icons.login),
              title: Text(l10n.settingsAutostart),
              subtitle: Text(l10n.settingsAutostartSubtitle),
              value: _autostart,
              onChanged: (v) async {
                await DesktopIntegration.setAutostart(v);
                setState(
                  () => _autostart = DesktopIntegration.autostartEnabled,
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.power_settings_new),
            title: Text(l10n.quitApp),
            subtitle: Text(l10n.quitAppSubtitle),
            onTap: DesktopIntegration.quit,
          ),
        ],
      ],
    );
  }
}
