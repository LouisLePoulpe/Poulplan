import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_router.dart';

import '../../../data/providers.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/holidays/school_holidays.dart';
import 'reminders_settings.dart';
import '../../lock/presentation/lock_settings.dart';
import '../../../l10n/generated/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final repository = ref.read(settingsRepositoryProvider);
    final theme = Theme.of(context);
    final weekdayFormat = DateFormat.EEEE(
      Localizations.localeOf(context).toString(),
    );

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          section(l10n.cloud),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(l10n.account),
            subtitle: Text(l10n.accountSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.account),
          ),
          section(l10n.dataSection),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l10n.backupsTitle),
            subtitle: Text(l10n.backupsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.backups),
          ),
          section(l10n.securitySection),
          const LockSettings(),
          section(l10n.settingsAppearance),
          ListTile(
            title: Text(l10n.settingsTheme),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<AppThemeMode>(
                segments: [
                  ButtonSegment(
                    value: AppThemeMode.system,
                    icon: const Icon(Icons.brightness_auto),
                    label: Text(l10n.themeSystem),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    icon: const Icon(Icons.light_mode),
                    label: Text(l10n.themeLight),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    icon: const Icon(Icons.dark_mode),
                    label: Text(l10n.themeDark),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => repository.setThemeMode(s.single),
              ),
            ),
          ),
          section(l10n.settingsCalendar),
          ListTile(
            title: Text(l10n.settingsFirstDayOfWeek),
            trailing: DropdownButton<int>(
              value: settings.firstDayOfWeek,
              onChanged: (v) {
                if (v != null) repository.setFirstDayOfWeek(v);
              },
              items: [
                for (final weekday in const [
                  DateTime.monday,
                  DateTime.saturday,
                  DateTime.sunday,
                ])
                  DropdownMenuItem(
                    value: weekday,
                    child: Text(
                      toBeginningOfSentenceCase(
                        // 5 January 2026 is a Monday.
                        weekdayFormat.format(DateTime(2026, 1, 4 + weekday)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: Text(l10n.categories),
            subtitle: Text(l10n.settingsCategoriesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.categories),
          ),
          section(l10n.settingsHolidays),
          SwitchListTile(
            secondary: const Icon(Icons.flag_outlined),
            title: Text(l10n.settingsShowHolidays),
            value: settings.showHolidays,
            onChanged: repository.setShowHolidays,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.map_outlined),
            title: Text(l10n.settingsAlsaceMoselle),
            subtitle: Text(l10n.settingsAlsaceMoselleSubtitle),
            value: settings.alsaceMoselle,
            onChanged: repository.setAlsaceMoselle,
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(l10n.settingsSchoolZone),
            trailing: DropdownButton<String?>(
              value: settings.schoolZone,
              onChanged: repository.setSchoolZone,
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.noSchoolZone)),
                for (final zone in schoolZones)
                  DropdownMenuItem(
                    value: zone,
                    child: Text(
                      zone.length == 1 ? l10n.schoolZone(zone) : zone,
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cake_outlined),
            title: Text(l10n.birthdays),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.birthdays),
          ),
          section(l10n.settingsReminders),
          const RemindersSettings(),
          section(l10n.settingsAbout),
          ListTile(
            leading: Image.asset(
              'assets/branding/poulplan-logo.png',
              width: 40,
              height: 40,
            ),
            title: Text(l10n.appTitle),
            subtitle: Text(l10n.aboutDescription),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.aboutLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationLegalese: 'GPL-3.0-or-later',
              applicationIcon: Image.asset(
                'assets/branding/poulplan-logo.png',
                width: 64,
                height: 64,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
