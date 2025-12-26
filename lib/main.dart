import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:healthcare/data/resources/gene/app_colors.dart';
import 'package:healthcare/router/app_router.dart';
import 'package:healthcare/router/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:healthcare/data/services/android_passive_listener_service.dart';
import 'package:healthcare/data/services/health_monitoring_trigger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:healthcare/data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize timezone for scheduled notifications
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

  // Initialize local notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      // Handle notification tap
      if (response.payload != null) {
        // You can add custom handler here
        debugPrint('Notification tapped with payload: ${response.payload}');
      }
    },
  );

  // Initialize NotificationService with the configured plugin
  NotificationService.initialize(flutterLocalNotificationsPlugin);
  debugPrint('✅ NotificationService initialized successfully');

  // Create notification channels for Android
  if (Platform.isAndroid) {
    // Healthcare notifications channel (for follow requests, chat, reviews, etc.)
    const AndroidNotificationChannel healthcareChannel =
        AndroidNotificationChannel(
          'healthcare_channel', // id
          'Healthcare Notifications', // name
          description: 'Thông báo về yêu cầu theo dõi, tin nhắn, nhận xét',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(healthcareChannel);
  }

  // Request notification permissions for Android 13+
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  // Request notification permissions for iOS
  if (Platform.isIOS) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // Initialize health monitoring trigger listener
  HealthMonitoringTrigger.initialize();

  // Auto-reapply passive listener if previously enabled (Android only)
  try {
    if (Platform.isAndroid) {
      final prefs = await SharedPreferences.getInstance();
      final on = prefs.getBool('passive_listener_enabled') ?? false;
      if (on) {
        // Fire-and-forget; WorkManager will schedule periodic + immediate drain
        await AndroidPassiveListenerService.enable();
      }
    }
  } catch (_) {}
  runApp(const ProviderScope(child: HealthCareApp()));
}

class HealthCareApp extends StatelessWidget {
  const HealthCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healthcare App',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      locale: const Locale('vi', 'VN'),
      theme: ThemeData(
        primarySwatch: MaterialColor(0xFF1976D2, const <int, Color>{
          50: Color(0xFFE3F2FD),
          100: Color(0xFFBBDEFB),
          200: Color(0xFF90CAF9),
          300: Color(0xFF64B5F6),
          400: Color(0xFF42A5F5),
          500: Color(0xFF1976D2),
          600: Color(0xFF1E88E5),
          700: Color(0xFF1976D2),
          800: Color(0xFF1565C0),
          900: Color(0xFF0D47A1),
        }),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primaryColor,
              width: 2,
            ),
          ),
        ),
      ),
      onGenerateRoute: AppRouter.generateRoute,
      home: const AuthWrapper(),
    );
  }
}
