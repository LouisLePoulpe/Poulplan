import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/platform/desktop_integration.dart';
import '../../core/platform/linux_tray.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../domain/calendar/day.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/widgets/widget_snapshot.dart';
import '../calendar/providers/calendar_providers.dart';

/// Android widget providers (see android/app/src/main/kotlin).
const _androidProviders = [
  'org.poulapp.poulplan.UpcomingWidgetProvider',
  'org.poulapp.poulplan.MonthWidgetProvider',
];

/// File read by the KDE Plasma widget (linux/plasmoid).
const linuxSnapshotFile = 'widget.json';

/// `poulplan://event/<id>`: opens an event from a widget.
Uri eventUri(String id) => Uri(scheme: 'poulplan', host: 'event', path: '/$id');

/// Event id of a widget click, if it targets an event.
String? eventIdFromUri(Uri? uri) {
  if (uri == null || uri.scheme != 'poulplan' || uri.host != 'event') {
    return null;
  }
  final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  return id.isEmpty ? null : id;
}

/// Keeps the home screen (Android) and desktop (KDE) widgets up to date:
/// a snapshot is exported a moment after any change of the displayed data.
class WidgetExporter {
  WidgetExporter(this._ref);

  final Ref _ref;
  final _subscriptions = <ProviderSubscription<Object?>>[];
  Timer? _debounce;
  Timer? _midnight;

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isLinux);

  void start() {
    if (!supported) return;
    _watch();
  }

  void _watch() {
    for (final s in _subscriptions) {
      s.close();
    }
    _subscriptions.clear();
    final today = _ref.read(todayProvider);
    final range = (
      first: today.firstDayOfMonth.addMonths(-1),
      last: today.firstDayOfMonth.addMonths(3).addDays(-1),
    );
    _subscriptions.add(
      _ref.container.listen(
        eventsByDayProvider(range),
        (_, next) => _schedule(),
        fireImmediately: true,
      ),
    );
    _subscriptions.add(
      _ref.container.listen(categoryColorsProvider, (_, _) => _schedule()),
    );
    // Move the window when the month changes (checked every hour).
    _midnight?.cancel();
    _midnight = Timer.periodic(const Duration(hours: 1), (_) {
      if (Day.today().month != today.month) _watch();
    });
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _export);
  }

  int _color(CalendarEvent e, Map<String, int> categories) => switch (e.kind) {
    EventKind.holiday => 0xFFE53935,
    EventKind.schoolHoliday => 0xFF78909C,
    EventKind.birthday => 0xFFD81B60,
    EventKind.event =>
      e.color ?? categories[e.categoryId] ?? BrandColors.brown.toARGB32(),
  };

  Future<void> _export() async {
    try {
      final today = _ref.read(todayProvider);
      final range = (
        first: today.firstDayOfMonth.addMonths(-1),
        last: today.firstDayOfMonth.addMonths(3).addDays(-1),
      );
      final byDay = _ref.read(eventsByDayProvider(range)).value;
      if (byDay == null) return;
      final events = {
        for (final list in byDay.values)
          for (final e in list) e.id: e,
      }.values;
      final location = _ref.read(displayLocationProvider);
      final categories = _ref.read(categoryColorsProvider);
      final snapshot = buildWidgetSnapshot(
        events,
        now: DateTime.now().toUtc(),
        toLocal: (utc) => tz.TZDateTime.from(utc, location),
        colorOf: (e) => _color(e, categories),
        firstDayOfWeek: _ref.read(settingsProvider).firstDayOfWeek,
      );
      final json = jsonEncode(snapshot.toJson());
      if (Platform.isAndroid) {
        await HomeWidget.saveWidgetData<String>('snapshot', json);
        for (final provider in _androidProviders) {
          await HomeWidget.updateWidget(qualifiedAndroidName: provider);
        }
      } else {
        final dir = await getApplicationSupportDirectory();
        final file = File(p.join(dir.path, linuxSnapshotFile));
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(json);
        await temp.rename(file.path);
        await _ref
            .read(linuxTrayProvider)
            .setDescription(
              nextEventDescription(snapshot, _ref.read(todayProvider)),
            );
      }
    } catch (error) {
      debugPrint('Widget export failed: $error');
    }
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.close();
    }
    _debounce?.cancel();
    _midnight?.cancel();
  }
}

/// Linux tray icon; its tooltip shows the next event.
final linuxTrayProvider = Provider<LinuxTray>((ref) {
  final tray = LinuxTray(
    onOpen: DesktopIntegration.showWindow,
    onQuit: DesktopIntegration.quit,
  );
  ref.onDispose(tray.dispose);
  return tray;
});

/// Tooltip text: « Prochain : Dentiste — Aujourd'hui à 14:30 ».
String nextEventDescription(WidgetSnapshot snapshot, Day today) {
  if (snapshot.upcoming.isEmpty) return 'Aucun événement à venir';
  final next = snapshot.upcoming.first;
  final day = next.localDay == today
      ? "Aujourd'hui"
      : next.localDay == today.addDays(1)
      ? 'Demain'
      : DateFormat.MMMEd('fr').format(next.localDay.toLocalMidnight());
  final time = next.time == null ? '' : ' à ${next.time}';
  return 'Prochain : ${next.title} — $day$time';
}

final widgetExporterProvider = Provider<WidgetExporter>((ref) {
  final exporter = WidgetExporter(ref);
  ref.onDispose(exporter.dispose);
  return exporter;
});
