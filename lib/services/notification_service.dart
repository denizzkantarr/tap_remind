import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/reminder.dart';
import '../main.dart';
import '../screens/reminder_dialog.dart';
import 'storage_service.dart';
import 'package:flutter/services.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  static const _iosChannel = MethodChannel('notif_channel');

  String _notificationTitle() {
    final settingsBox = Hive.box('settings');
    final lang = settingsBox.get('language', defaultValue: 'tr') as String;
    return lang == 'en' ? 'Reminder' : 'Hatırlatıcı';
  }

  String _notificationBody(Reminder reminder) {
    if (reminder.transcript.isNotEmpty) return reminder.transcript;
    final settingsBox = Hive.box('settings');
    final lang = settingsBox.get('language', defaultValue: 'tr') as String;
    return lang == 'en' ? 'Voice reminder' : 'Sesli hatırlatıcı';
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }
    }

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    const androidSettings = AndroidInitializationSettings('tapremind');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _isInitialized = true;
  }

  Future<void> testForegroundNow() async {
    if (!_isInitialized) await initialize();

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Hatırlatıcılar',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(iOS: iosDetails, android: androidDetails);

    await _notifications.show(999999, 'Foreground Test', 'Test', details);
  }

  Future<void> clearAllIosNotifications() async {
    await _notifications.cancelAll();

    if (Platform.isIOS) {
      await _iosChannel.invokeMethod('clearDelivered');
    }
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final reminder = await StorageService().getReminder(payload);
    if (reminder == null) return;

    if (!ctx.mounted) return;

    showDialog(
      context: ctx,
      builder: (_) => ReminderDialog(reminder: reminder),
    );
  }

  Future<bool> _ensureExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.scheduleExactAlarm.request();
    return result.isGranted;
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    if (!_isInitialized) await initialize();

    await _ensureExactAlarmPermission();

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      const channel = AndroidNotificationChannel(
        'reminder_channel',
        'Hatırlatıcılar',
        description: 'Sesli hatırlatıcı bildirimleri',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidImpl.createNotificationChannel(channel);
    }

    final location = tz.getLocation('Europe/Istanbul');
    final tz.TZDateTime scheduledDate = reminder.scheduledTime is tz.TZDateTime
        ? reminder.scheduledTime as tz.TZDateTime
        : tz.TZDateTime.from(reminder.scheduledTime, location);

    final now = tz.TZDateTime.now(location);
    final tz.TZDateTime targetDate = scheduledDate.isBefore(now)
        ? now.add(const Duration(seconds: 10))
        : scheduledDate;

    final androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Hatırlatıcılar',
      channelDescription: 'Sesli hatırlatıcı bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
      icon: 'tapremind',
      largeIcon: const DrawableResourceAndroidBitmap('tapremind'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _notifications.zonedSchedule(
        reminder.id.hashCode,
        _notificationTitle(),
        _notificationBody(reminder),
        targetDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id,
      );
    } catch (e) {
      // Scheduling failed — notification won't fire but reminder is still saved.
    }
  }

  Future<void> cancelReminder(String reminderId) async {
    await _notifications.cancel(reminderId.hashCode);
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  Future<void> showOverdueNotification(Reminder reminder) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Hatırlatıcılar',
      channelDescription: 'Sesli hatırlatıcı bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: 'logobell',
      largeIcon: const DrawableResourceAndroidBitmap('logobell'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      reminder.id.hashCode,
      _notificationTitle(),
      _notificationBody(reminder),
      details,
      payload: reminder.id,
    );
  }
}
