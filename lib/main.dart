import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:easy_localization/easy_localization.dart';

// 🔥 EKSİK OLANLAR — BUNLAR OLMAZSA iOS SCHEDULED ÇALIŞMAZ
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'models/reminder.dart';

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
  } catch (_) {}

  // Permissions
  // iOS'ta notification permission flutter_local_notifications tarafından otomatik istenir
  // permission_handler ile çakışmaması için burada istemiyoruz
  
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
      startLocale: savedLanguage == 'en' ? const Locale('en') : const Locale('tr'),
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
