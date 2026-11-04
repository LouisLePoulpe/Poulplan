import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'features/lock/lock_controller.dart';
import 'features/backup/presentation/backup_page.dart' show formatBytes;
import 'features/storage/storage_report.dart';
import 'core/format/formatters.dart';
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
  Timer? _storageCheck;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// When the device is almost full, proposes the cleanup (once a week).
  Future<void> _checkStorage() async {
    try {
      final report = await ref.read(storageReportProvider.future);
      if (!report.proposeCleanup) return;
      final settings = ref.read(settingsRepositoryProvider);
      final last = int.tryParse(
        await settings.getValue('storage_proposed') ?? '',
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      if (last != null && now - last < const Duration(days: 7).inMilliseconds) {
        return;
      }
      await settings.setValue('storage_proposed', '$now');
      final messenger = _messenger.currentState;
      if (messenger == null || !messenger.mounted) return;
      final l10n = AppLocalizations.of(messenger.context);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(
            l10n.storageLow(
              formatBytes(report.reclaimableBytes, localeOf(messenger.context)),
            ),
          ),
          action: SnackBarAction(
            label: l10n.storageClean,
            onPressed: () => ref.read(routerProvider).push(Routes.storage),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Storage check failed: $e');
    }
  }

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
    _storageCheck = Timer(const Duration(seconds: 20), _checkStorage);
  }

  @override
  void dispose() {
    _opened?.cancel();
    _widgetClicks?.cancel();
    _desktopOpen?.cancel();
    _storageCheck?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
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
