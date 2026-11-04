import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'features/lock/lock_controller.dart';
import 'features/lock/presentation/lock_screen.dart';
import 'core/platform/desktop_integration.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/reminders/reminder_scheduler.dart';
import 'features/widgets/widget_exporter.dart';
import 'l10n/generated/app_localizations.dart';

class PoulplanApp extends ConsumerStatefulWidget {
  const PoulplanApp({super.key});

  @override
  ConsumerState<PoulplanApp> createState() => _PoulplanAppState();
}

class _PoulplanAppState extends ConsumerState<PoulplanApp> {
  StreamSubscription<String>? _opened;
  StreamSubscription<Uri?>? _widgetClicks;
  StreamSubscription<Uri>? _desktopOpen;

  @override
  void initState() {
    super.initState();
    // Tapped reminder: show the window (Linux, hidden) and open the event.
    _opened = ref.read(notificationServiceProvider).openedEvents.listen((id) {
      DesktopIntegration.showWindow();
      ref.read(routerProvider).push(Routes.event(id));
    });
    // Home screen widget (Android) and KDE widget (Linux) taps: open an
    // event, create one, or just open the app.
    void handleWidget(Uri? uri) {
      if (uri == null || uri.scheme != 'poulplan') return;
      DesktopIntegration.showWindow();
      final router = ref.read(routerProvider);
      final id = eventIdFromUri(uri);
      if (id != null) {
        router.push(Routes.event(id));
      } else if (isNewEventUri(uri)) {
        router.push(Routes.newEvent);
      }
    }

    if (WidgetExporter.supported && !DesktopIntegration.isLinux) {
      _widgetClicks = HomeWidget.widgetClicked.listen(handleWidget);
      HomeWidget.initiallyLaunchedFromHomeWidget().then(handleWidget);
    }
    _desktopOpen = DesktopIntegration.widgetActions.listen(handleWidget);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(reminderSchedulerProvider).askPermissionOnce(),
    );
  }

  @override
  void dispose() {
    _opened?.cancel();
    _widgetClicks?.cancel();
    _desktopOpen?.cancel();
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
      builder: (context, child) => Stack(
        children: [
          ?child,
          if (ref.watch(lockControllerProvider.select((l) => l.locked)))
            // Above the router's navigator: its own overlay for the field.
            Positioned.fill(
              child: Overlay(
                initialEntries: [
                  OverlayEntry(builder: (context) => const LockScreen()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
