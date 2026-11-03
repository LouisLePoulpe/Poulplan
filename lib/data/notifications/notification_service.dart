import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/reminders/reminders.dart';

const _channelId = 'reminders';
const _channelName = 'Rappels';
const ackAction = 'ack';
const snoozeAction = 'snooze';
const snoozeMinutes = 10;

/// What a notification carries, to reopen the event or snooze it even when
/// the app was not running.
@immutable
class ReminderPayload {
  const ReminderPayload({
    required this.eventId,
    required this.title,
    required this.body,
    required this.notificationId,
  });

  factory ReminderPayload.decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    return ReminderPayload(
      eventId: json['eventId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      notificationId: json['id'] as int,
    );
  }

  final String eventId;
  final String title;
  final String body;
  final int notificationId;

  String encode() => jsonEncode({
    'eventId': eventId,
    'title': title,
    'body': body,
    'id': notificationId,
  });
}

NotificationDetails _details() => NotificationDetails(
  android: const AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Rappels des événements du calendrier',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    // Stays until the user acknowledges it.
    ongoing: true,
    autoCancel: false,
    icon: 'ic_notification',
    actions: [
      AndroidNotificationAction(
        ackAction,
        "C'est noté",
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        snoozeAction,
        'Reporter $snoozeMinutes min',
        cancelNotification: true,
      ),
    ],
  ),
  linux: const LinuxNotificationDetails(
    // KDE/GNOME keep critical notifications until dismissed.
    urgency: LinuxNotificationUrgency.critical,
    resident: true,
    actions: [
      LinuxNotificationAction(key: ackAction, label: "C'est noté"),
      LinuxNotificationAction(
        key: snoozeAction,
        label: 'Reporter $snoozeMinutes min',
      ),
    ],
  ),
);

/// Schedules [payload] again in [snoozeMinutes] (also from the background
/// isolate on Android, hence a top-level function).
Future<void> snoozeReminder(
  FlutterLocalNotificationsPlugin plugin,
  ReminderPayload payload,
) => plugin.zonedSchedule(
  id: payload.notificationId | snoozeIdFlag,
  title: payload.title,
  body: payload.body,
  scheduledDate: tz.TZDateTime.now(tz.UTC)
      .add(const Duration(minutes: snoozeMinutes)),
  notificationDetails: _details(),
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  payload: payload.encode(),
);

/// Android: notification button pressed while the app is not running.
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  if (response.actionId != snoozeAction || response.payload == null) return;
  tzdata.initializeTimeZones();
  final plugin = FlutterLocalNotificationsPlugin();
  unawaited(
    plugin
        .initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_notification'),
          ),
        )
        .then(
          (_) =>
              snoozeReminder(plugin, ReminderPayload.decode(response.payload!)),
        ),
  );
}

/// Platform notifications for reminders (Android and Linux).
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _opened = StreamController<String>.broadcast();
  bool _ready = false;

  /// Event ids whose notification was tapped.
  Stream<String> get openedEvents => _opened.stream;

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isLinux);

  /// Android schedules alarms in the system (works with the app closed);
  /// on Linux the app shows notifications itself while running.
  static bool get systemScheduling => !kIsWeb && Platform.isAndroid;

  Future<void> init() async {
    if (!supported || _ready) return;
    _ready =
        await _plugin.initialize(
          settings: InitializationSettings(
            android: const AndroidInitializationSettings('ic_notification'),
            linux: LinuxInitializationSettings(
              defaultActionName: 'Ouvrir',
              defaultIcon: AssetsLinuxIcon('assets/branding/poulplan-logo.png'),
            ),
          ),
          onDidReceiveNotificationResponse: _onResponse,
          onDidReceiveBackgroundNotificationResponse:
              onBackgroundNotificationResponse,
        ) ??
        false;
    // Not implemented on Linux (the app is already running when tapped).
    if (!systemScheduling) return;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      scheduleMicrotask(
        () => _opened.add(ReminderPayload.decode(payload).eventId),
      );
    }
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload == null
        ? null
        : ReminderPayload.decode(response.payload!);
    if (payload == null) return;
    switch (response.actionId) {
      case snoozeAction:
        if (systemScheduling) {
          unawaited(snoozeReminder(_plugin, payload));
        } else {
          // Linux: no system scheduler, a timer in the running app.
          unawaited(_plugin.cancel(id: payload.notificationId));
          Timer(
            const Duration(minutes: snoozeMinutes),
            () => _showPayload(payload.notificationId | snoozeIdFlag, payload),
          );
        }
      case ackAction:
        unawaited(_plugin.cancel(id: payload.notificationId));
      default:
        _opened.add(payload.eventId);
    }
  }

  /// Asks for the notification permission (Android 13+). Returns whether
  /// notifications can be shown.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return supported;
    final granted = await android.requestNotificationsPermission() ?? false;
    if (await android.canScheduleExactNotifications() == false) {
      await android.requestExactAlarmsPermission();
    }
    return granted;
  }

  Future<bool> permissionGranted() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return supported;
    return await android.areNotificationsEnabled() ?? false;
  }

  ReminderPayload _payload(ReminderFire fire, String body) => ReminderPayload(
    eventId: fire.event.id,
    title: fire.event.title,
    body: body,
    notificationId: fire.notificationId,
  );

  Future<void> _showPayload(int id, ReminderPayload payload) => _plugin.show(
    id: id,
    title: payload.title,
    body: payload.body,
    notificationDetails: _details(),
    payload: payload.encode(),
  );

  /// Shows [fire] now (Linux scheduler, test notification).
  Future<void> show(ReminderFire fire, String body) async {
    if (!_ready) return;
    await _showPayload(fire.notificationId, _payload(fire, body));
  }

  /// Android: makes the system alarms match [fires] exactly (snoozed
  /// reminders are left alone).
  Future<void> scheduleAll(
    List<ReminderFire> fires,
    String Function(ReminderFire) body,
  ) async {
    if (!_ready || !systemScheduling) return;
    final wanted = {for (final f in fires) f.notificationId: f};
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id & snoozeIdFlag == 0 && !wanted.containsKey(p.id)) {
        await _plugin.cancel(id: p.id);
      }
    }
    for (final fire in fires) {
      final payload = _payload(fire, body(fire));
      await _plugin.zonedSchedule(
        id: fire.notificationId,
        title: payload.title,
        body: payload.body,
        scheduledDate: tz.TZDateTime.from(fire.fireAt, tz.UTC),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload.encode(),
      );
    }
  }

  Future<void> dispose() => _opened.close();
}
