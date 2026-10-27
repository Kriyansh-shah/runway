/// [ReminderScheduler] on iPhone and Android, through
/// flutter_local_notifications. Everything is scheduled on the phone.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

class LocalReminders implements ReminderScheduler {
  LocalReminders._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription:
          'Bills due tomorrow, the evening check-in and the '
          'weekly recap',
      importance: Importance.defaultImportance,
      icon: 'ic_notification',
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Sets up the plugin; [onTap] gets what a tapped reminder should open,
  /// including the one that launched the app. Call once, on a phone.
  static Future<LocalReminders> start(void Function(ReminderTap) onTap) async {
    tz_data.initializeTimeZones();
    void handle(String? payload) {
      final tap = ReminderTap.values.asNameMap()[payload];
      if (tap != null) onTap(tap);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        // Permission is asked for when a reminder is first turned on, not
        // at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => handle(r.payload),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      handle(launch!.notificationResponse?.payload);
    }
    return LocalReminders._();
  }

  @override
  bool get supported => true;

  @override
  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _plugin.cancelAll();
    for (final r in reminders) {
      // An instant, worked out from local time now. The plan is redone
      // every time the app opens, so clock changes catch up.
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.tap.name,
      );
    }
  }
}
