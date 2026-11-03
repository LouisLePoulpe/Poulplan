import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/platform/desktop_integration.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/reminders/reminder_scheduler.dart';
import 'l10n/generated/app_localizations.dart';

class PoulplanApp extends ConsumerStatefulWidget {
  const PoulplanApp({super.key});

  @override
  ConsumerState<PoulplanApp> createState() => _PoulplanAppState();
}

class _PoulplanAppState extends ConsumerState<PoulplanApp> {
  StreamSubscription<String>? _opened;

  @override
  void initState() {
    super.initState();
    // Tapped reminder: show the window (Linux, hidden) and open the event.
    _opened = ref.read(notificationServiceProvider).openedEvents.listen((id) {
      DesktopIntegration.showWindow();
      ref.read(routerProvider).push(Routes.event(id));
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(reminderSchedulerProvider).askPermissionOnce(),
    );
  }

  @override
  void dispose() {
    _opened?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: toFlutterThemeMode(themeMode),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
