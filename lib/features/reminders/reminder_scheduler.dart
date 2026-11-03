import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/format/formatters.dart';
import '../../data/db/app_database.dart';
import '../../data/notifications/notification_service.dart';
import '../../data/providers.dart';
import '../../domain/calendar/day.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/reminders/reminders.dart';
import '../calendar/providers/calendar_providers.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Body of a reminder: « Aujourd'hui à 14:30 · Lieu ».
String reminderBody(
  CalendarEvent event,
  DateTime now,
  DateTime Function(DateTime) toLocal,
) {
  final start = toLocal(event.start);
  final today = Day.fromDateTime(toLocal(now));
  final day = event.allDay
      ? Day.fromDateTime(event.start)
      : Day.fromDateTime(start);
  final String when;
  if (day == today) {
    when = "Aujourd'hui";
  } else if (day == today.addDays(1)) {
    when = 'Demain';
  } else {
    when = toBeginningOfSentenceCase(
      DateFormat.MMMEd('fr').format(day.toLocalMidnight()),
      'fr',
    );
  }
  final time = event.allDay ? '' : ' à ${formatClock(start)}';
  return [
    '$when$time',
    if (event.location?.isNotEmpty ?? false) event.location!,
  ].join(' · ');
}

/// Keeps platform notifications in line with the events' reminders.
///
/// - Android: exact system alarms for the next [horizon] (they fire with the
///   app closed and are restored after a reboot by the plugin).
/// - Linux: the running app checks every [_tick] and shows due reminders;
///   at startup it also shows those missed during the last 24 h.
class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;
  static const horizon = Duration(days: 30);
  static const _tick = Duration(seconds: 30);
  static const _resubscribe = Duration(hours: 6);
  static const _checkedKey = 'reminders_checked_at';
  static const _askedKey = 'notification_permission_asked';
  static const _maxCatchUp = Duration(hours: 24);

  StreamSubscription<List<CalendarEvent>>? _events;
  Timer? _debounce;
  Timer? _ticker;
  Timer? _window;
  List<CalendarEvent> _latest = const [];

  NotificationService get _service => _ref.read(notificationServiceProvider);
  AppDatabase get _db => _ref.read(databaseProvider);
  tz.Location get _display => _ref.read(displayLocationProvider);

  Future<void> start() async {
    if (!NotificationService.supported) return;
    await _service.init();
    if (NotificationService.systemScheduling) await _askPermissionOnce();
    _subscribe();
    _window = Timer.periodic(_resubscribe, (_) => _subscribe());
    if (!NotificationService.systemScheduling) {
      await _checkDue(startup: true);
      _ticker = Timer.periodic(_tick, (_) => _checkDue());
    }
  }

  /// Android 13+: the notification permission is asked once, at the first
  /// launch; afterwards only from the settings.
  Future<void> _askPermissionOnce() async {
    final asked = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(_askedKey))).getSingleOrNull();
    if (asked != null) return;
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: _askedKey, value: 'true'),
        );
    await _service.requestPermission();
  }

  void _subscribe() {
    _events?.cancel();
    final today = Day.fromDateTime(
      tz.TZDateTime.from(DateTime.now().toUtc(), _display),
    );
    _events = _ref
        .read(eventRepositoryProvider)
        .watchBetween(
          today.addDays(-2),
          today.addDays(horizon.inDays + 2),
          display: _display,
          holidays: _ref.read(holidayCalendarProvider),
        )
        .listen((events) {
          _latest = events;
          _debounce?.cancel();
          _debounce = Timer(const Duration(seconds: 1), _reschedule);
        });
  }

  String _body(ReminderFire fire) => reminderBody(
    fire.event,
    DateTime.now().toUtc(),
    (utc) => tz.TZDateTime.from(utc, _display),
  );

  Future<void> _reschedule() async {
    if (!NotificationService.systemScheduling) return;
    try {
      await _service.scheduleAll(
        upcomingReminders(
          _latest,
          now: DateTime.now().toUtc(),
          horizon: horizon,
          display: _display,
        ),
        _body,
      );
    } catch (error) {
      debugPrint('Reminder scheduling failed: $error');
    }
  }

  Future<void> _checkDue({bool startup = false}) async {
    final now = DateTime.now().toUtc();
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(_checkedKey))).getSingleOrNull();
    var since = DateTime.tryParse(row?.value ?? '') ?? now;
    if (since.isBefore(now.subtract(_maxCatchUp))) {
      since = now.subtract(_maxCatchUp);
    }
    for (final fire in dueReminders(
      _latest,
      since: since,
      now: now,
      display: _display,
    )) {
      await _service.show(fire, _body(fire));
      if (kDebugMode) debugPrint('Reminder shown: ${fire.event.title}');
    }
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(
            key: const Value(_checkedKey),
            value: Value(now.toIso8601String()),
          ),
        );
  }

  /// Shows a test notification now (and, on Android, another one through
  /// the system alarm in one minute, to test with the screen locked).
  Future<void> sendTest() async {
    final now = DateTime.now().toUtc();
    CalendarEvent probe(String title, DateTime at) => CalendarEvent(
      id: 'test-${at.millisecondsSinceEpoch}',
      title: title,
      start: at,
      end: at.add(const Duration(minutes: 30)),
      timeZone: 'UTC',
      reminders: const [0],
      createdAt: now,
      updatedAt: now,
    );
    final instant = probe('Poulplan — notification de test', now);
    await _service.show(
      ReminderFire(
        event: instant,
        minutesBefore: 0,
        fireAt: now,
        notificationId: reminderNotificationId(instant.id, 0),
      ),
      'Les rappels fonctionnent.',
    );
    if (NotificationService.systemScheduling) {
      final later = probe(
        'Poulplan — rappel de test (1 min)',
        now.add(const Duration(minutes: 1)),
      );
      final fires = upcomingReminders(
        [..._latest, later],
        now: now,
        horizon: horizon,
        display: _display,
      );
      await _service.scheduleAll(fires, _body);
    }
  }

  void dispose() {
    _events?.cancel();
    _debounce?.cancel();
    _ticker?.cancel();
    _window?.cancel();
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
