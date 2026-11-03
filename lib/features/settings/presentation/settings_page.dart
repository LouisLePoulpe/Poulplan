import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/providers.dart';
import '../../../domain/entities/app_settings.dart';
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
