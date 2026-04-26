import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models/reminder.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final NotificationService notificationService = NotificationService();

final StorageService storageService = StorageService();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 MUTLAKA GEREK — iOS SCHEDULED BUNDAN SONRA ÇALIŞIR
  tz.initializeTimeZones();

  // iOS'ta timezone'u manuel olarak ayarla (Türkiye için)
  // Cihazın timezone'unu al ve kullan
  try {
    final location = tz.getLocation('Europe/Istanbul');
    tz.setLocalLocation(location);
  } catch (e) {
    print('⚠️ Could not set timezone to Europe/Istanbul: $e');
    // Fallback: cihazın timezone'unu kullan
    try {
      final locationName = DateTime.now().timeZoneName;
      print('Using device timezone: $locationName');
    } catch (e2) {
      print('⚠️ Could not get device timezone: $e2');
    }
  }

  // Android için exact alarm permission
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }

  await initializeDateFormatting('tr_TR', null);

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ReminderAdapter());
  }

  await Hive.openBox('settings');

  // Load saved language from settings, default to Turkish
  final settingsBox = Hive.box('settings');
  final savedLanguage = settingsBox.get('language', defaultValue: 'tr');

  // Initialize easy_localization
  await EasyLocalization.ensureInitialized();

  await storageService.init();

  await notificationService.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      startLocale: savedLanguage == 'en'
          ? const Locale('en')
          : const Locale('tr'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tap Remind',
      navigatorKey: navigatorKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35), // Orange color
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
