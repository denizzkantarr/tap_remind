import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

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

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android 13+ requires runtime notification permission
    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        final result = await Permission.notification.request();
        print('🔔 Notification permission request result: $result');
        if (!result.isGranted) {
          print(
            '⚠️ Notification permission not granted; notifications may be blocked.',
          );
        }
      }
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    print('🍏 iOS permission granted: $granted');
    const androidSettings = AndroidInitializationSettings(
      'logobell', // Bildirimlerde gösterilecek küçük ikon
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,

      // ✅ Uygulama AÇIKKEN (foreground) banner + ses + badge göster
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initResult = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    print('📱 Notification service initialization result: $initResult');

    // iOS'ta notification permission flutter_local_notifications tarafından otomatik istenir
    // permission_handler ile çakışmaması için burada kontrol etmiyoruz

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

    const details = NotificationDetails(
      iOS: iosDetails,
      android: androidDetails,
    );

    await _notifications.show(
      999999,
      'Foreground Test',
      'App açıkken banner görünüyor mu?',
      details,
    );
  }

  Future<void> clearAllIosNotifications() async {
    await _notifications.cancelAll(); // Flutter plugin pending

    if (Platform.isIOS) {
      await _iosChannel.invokeMethod(
        'clearDelivered',
      ); // ✅ native delivered+pending
    }
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    final reminder = await StorageService().getReminder(payload);
    final ctx = navigatorKey.currentContext;
    if (reminder == null || ctx == null) return;

    showDialog(
      context: ctx,
      builder: (_) => ReminderDialog(reminder: reminder),
    );
  }

  Future<bool> _ensureExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    print('Exact alarm permission status: $status');

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      print(
        'WARNING: Exact alarm permission permanently denied. User must enable in settings.',
      );
      return false;
    }

    final result = await Permission.scheduleExactAlarm.request();
    print('Permission request result: $result');
    return result.isGranted;
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Android için izin kontrolü
    await _ensureExactAlarmPermission();

    // Android 8+ için kanal
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
      print('Notification channel created: reminder_channel');
    }

    // scheduledTime → TZDateTime
    // iOS'ta timezone sorununu çözmek için Europe/Istanbul kullan
    final location = tz.getLocation('Europe/Istanbul');

    final tz.TZDateTime scheduledDate = reminder.scheduledTime is tz.TZDateTime
        ? reminder.scheduledTime as tz.TZDateTime
        : tz.TZDateTime.from(reminder.scheduledTime, location);

    final now = tz.TZDateTime.now(location);
    final tz.TZDateTime targetDate = scheduledDate.isBefore(now)
        ? now.add(const Duration(seconds: 10))
        : scheduledDate;
    if (scheduledDate.isBefore(now)) {
      print(
        'Warning: Scheduled time is in the past ($scheduledDate). Auto-adjusting to $targetDate',
      );
    }

    // Debug: zamanları hem local hem UTC olarak göster
    print('Scheduling notification for:');
    print('  Scheduled (local): $scheduledDate');
    print('  Scheduled (UTC): ${scheduledDate.toUtc()}');
    print('  Now (local): $now');
    print('  Now (UTC): ${now.toUtc()}');
    final diff = scheduledDate.difference(now);
    print(
      '  Time difference: ${diff.inSeconds} seconds (${diff.inMinutes} minutes / ${(diff.inMinutes / 60).toStringAsFixed(1)} hours)',
    );

    final androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Hatırlatıcılar',
      channelDescription: 'Sesli hatırlatıcı bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
      icon: 'logobell', // Küçük ikon
      largeIcon: const DrawableResourceAndroidBitmap(
        'logobell',
      ), // Banner'da gösterilecek büyük logo
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      // iOS'ta notification permission flutter_local_notifications tarafından otomatik yönetilir
      // permission_handler ile kontrol etmeye gerek yok, çakışma yaratabilir
      // iOS'ta initialize() çağrıldığında otomatik olarak izin istenir

      print('📅 Scheduling notification with zonedSchedule...');
      print('   Notification ID: ${reminder.id.hashCode}');
      print('   Scheduled time: $scheduledDate');
      print('   Title: Hatırlatıcı');
      print(
        '   Body: ${reminder.transcript.isEmpty ? "Sesli hatırlatıcı" : reminder.transcript}',
      );

      await _notifications.zonedSchedule(
        reminder.id.hashCode,
        'Hatırlatıcı',
        reminder.transcript.isEmpty ? 'Sesli hatırlatıcı' : reminder.transcript,
        targetDate, // ✅ TZDateTime (adjusted if needed)
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id,
      );
      print('✅ Notification scheduled successfully');

      // Debug için pending listesi - daha detaylı
      final pending = await _notifications.pendingNotificationRequests();
      print('Total pending notifications: ${pending.length}');

      // Tüm pending notifications'ı listele
      for (var notif in pending) {
        print(
          '  - ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}',
        );
      }

      final exists = pending.any((n) => n.id == reminder.id.hashCode);
      print(
        exists
            ? '✅ Our notification found in pending list'
            : '⚠️ Our notification NOT found in pending list',
      );

      // iOS'ta bildirimlerin çalışıp çalışmadığını kontrol et
      final iosImpl = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImpl != null) {
        final activeNotifications = await iosImpl.getActiveNotifications();
        print('📱 iOS active notifications: ${activeNotifications.length}');
      }
    } catch (e, stackTrace) {
      print('Error scheduling notification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> cancelReminder(String reminderId) async {
    await _notifications.cancel(reminderId.hashCode);
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  Future<void> showOverdueNotification(Reminder reminder) async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Hatırlatıcılar',
      channelDescription: 'Sesli hatırlatıcı bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: 'logobell', // Küçük ikon
      largeIcon: const DrawableResourceAndroidBitmap(
        'logobell',
      ), // Banner'da gösterilecek büyük logo
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      reminder.id.hashCode,
      'Hatırlatıcı',
      reminder.transcript.isEmpty ? 'Sesli hatırlatıcı' : reminder.transcript,
      details,
      payload: reminder.id,
    );

    print('Overdue notification shown for reminder: ${reminder.id}');
  }
}
