import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'engagement_logic.dart';

/// Schedules the daily study reminders. Failures (denied permission, missing
/// plugin) never reach the learner: reminders are a nice-to-have.
abstract class ReminderScheduler {
  /// Asks for notification permission; true when reminders can be shown.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [slots].
  Future<void> replaceAll(List<ReminderSlot> slots);
}

/// Used where no platform notifications exist (tests, unsupported hosts).
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> replaceAll(List<ReminderSlot> slots) async {}
}

/// Local notifications via flutter_local_notifications. Uses inexact
/// scheduling (no exact-alarm permission) and one-shot notifications at
/// absolute instants, so no device time-zone database is needed.
class LocalNotificationReminderScheduler implements ReminderScheduler {
  LocalNotificationReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _initialized;

  static const _firstId = 7100;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_study_reminder',
      'Daily study reminder',
      channelDescription: 'A daily nudge to keep your learning streak.',
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<bool> _ensureInitialized() => _initialized ??= _initialize();

  Future<bool> _initialize() async {
    try {
      return await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              // Permission is asked only when the learner turns reminders on.
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
            ),
          ) ??
          false;
    } on Object catch (error) {
      debugPrint('Reminder init failed: $error');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _ensureInitialized()) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      return false;
    } on Object catch (error) {
      debugPrint('Reminder permission request failed: $error');
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<ReminderSlot> slots) async {
    if (!await _ensureInitialized()) return;
    try {
      for (var i = 0; i < reminderDaysAhead; i++) {
        await _plugin.cancel(id: _firstId + i);
      }
      for (var i = 0; i < slots.length && i < reminderDaysAhead; i++) {
        final slot = slots[i];
        await _plugin.zonedSchedule(
          id: _firstId + i,
          title: slot.title,
          body: slot.body,
          scheduledDate: tz.TZDateTime.from(slot.at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on Object catch (error) {
      debugPrint('Reminder scheduling failed: $error');
    }
  }
}
