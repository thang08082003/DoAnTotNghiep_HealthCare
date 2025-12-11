import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/health_metrics_providers.dart';
import '../providers/health_monitoring_provider.dart';
import '../data/services/scheduled_notification_service.dart';
import '../screens/login/login_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/forgot_password/forgot_password_screen.dart';
import '../screens/user_setup/user_setup_screen.dart';
import '../screens/user_setup/disease_doctor_selection/disease_doctor_selection_screen.dart';
import '../screens/user_setup/doctor_specialty_selection/doctor_specialty_selection_screen.dart';
import '../screens/home/home_page.dart';
import '../screens/permissions/permissions_request_screen.dart';
import '../viewmodels/notifications/local_notifications_view_model.dart';
import '../viewmodels/notifications/notifications_view_model.dart';
import '../viewmodels/foreground/foreground_service_view_model.dart';
import '../viewmodels/passive_listener/passive_listener_view_model.dart';
import '../components/incoming_call_listener.dart';
import '../data/services/session_service.dart';
import '../components/health/latest_health_alert_widget.dart';
import '../screens/health_alerts/health_alerts_screen.dart';

class AppRouter {
  // Route names
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String userSetup = '/user-setup';
  static const String diseaseDoctorSelection = '/disease-doctor-selection';
  static const String doctorSpecialtySelection = '/doctor-specialty-selection';
  // static const String dashboard = '/dashboard'; // deprecated

  // Generate routes
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );

      case forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
          settings: settings,
        );

      case userSetup:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => UserSetupScreen(
            uid: args?['uid'] ?? '',
            email: args?['email'] ?? '',
          ),
          settings: settings,
        );

      case diseaseDoctorSelection:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DiseaseDoctorSelectionScreen(
            patientId: args?['patientId'] ?? '',
            patientName: args?['patientName'] ?? '',
            patientEmail: args?['patientEmail'] ?? '',
            phone: args?['phone'],
            age: args?['age'],
            gender: args?['gender'],
            medicalHistory: args?['medicalHistory'],
          ),
          settings: settings,
        );

      case doctorSpecialtySelection:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DoctorSpecialtySelectionScreen(
            doctorId: args?['doctorId'] ?? '',
            doctorName: args?['doctorName'] ?? '',
            doctorEmail: args?['doctorEmail'] ?? '',
            yearsExperience: args?['yearsExperience'],
            phone: args?['phone'],
            description: args?['description'],
            gender: args?['gender'],
          ),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Không tìm thấy trang'))),
        );
    }
  }

  // Navigation helpers
  static void pushLogin(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(login, (route) => false);
  }

  static void pushRegister(BuildContext context) {
    Navigator.of(context).pushNamed(register);
  }

  static void pushUserSetup(
    BuildContext context, {
    required String uid,
    required String email,
  }) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      userSetup,
      (route) => false,
      arguments: {'uid': uid, 'email': email},
    );
  }

  static void pushDiseaseDoctorSelection(
    BuildContext context, {
    required String patientId,
    required String patientName,
    required String patientEmail,
    String? phone,
    int? age,
    String? gender,
    String? medicalHistory,
  }) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      diseaseDoctorSelection,
      (route) => false,
      arguments: {
        'patientId': patientId,
        'patientName': patientName,
        'patientEmail': patientEmail,
        'phone': phone,
        'age': age,
        'gender': gender,
        'medicalHistory': medicalHistory,
      },
    );
  }

  static void pushDoctorSpecialtySelection(
    BuildContext context, {
    required String doctorId,
    required String doctorName,
    required String doctorEmail,
    int? yearsExperience,
    String? phone,
    String? description,
    String? gender,
  }) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      doctorSpecialtySelection,
      (route) => false,
      arguments: {
        'doctorId': doctorId,
        'doctorName': doctorName,
        'doctorEmail': doctorEmail,
        'yearsExperience': yearsExperience,
        'phone': phone,
        'description': description,
        'gender': gender,
      },
    );
  }
}

// Auth Wrapper
class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper>
    with WidgetsBindingObserver {
  String? _currentUserId;
  bool?
  _permissionsRequested; // null = checking, true = granted/skipped, false = need to request
  StreamSubscription<bool>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsStatus();
  }

  Future<void> _checkPermissionsStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final requested = prefs.getBool('permissions_requested') ?? false;
    if (mounted) {
      setState(() {
        _permissionsRequested = requested;
      });
    }
  }

  Future<void> _markPermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_requested', true);
    if (mounted) {
      setState(() {
        _permissionsRequested = true;
      });
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showKickedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Tài khoản đã được đăng nhập từ thiết bị khác.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Sign out
              await ref.read(authRepositoryProvider).signOut();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_currentUserId == null) return;
    if (state == AppLifecycleState.paused) {
      // App goes to background
      ref.read(foregroundServiceViewModelProvider).start(_currentUserId!);
    } else if (state == AppLifecycleState.resumed) {
      // App returns to foreground
      ref.read(foregroundServiceViewModelProvider).stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final authState = ref.watch(authProvider);

    // Check if still loading permissions status
    if (_permissionsRequested == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show permissions request screen if not requested yet
    if (_permissionsRequested == false) {
      return PermissionsRequestScreen(
        onPermissionsGranted: _markPermissionsRequested,
      );
    }

    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState.isAuthenticated && authState.uid != null) {
      // User is authenticated, check if profile exists
      return Consumer(
        builder: (context, ref, child) {
          return FutureBuilder(
            future: ref.read(userRepositoryProvider).userExists(authState.uid!),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (profileSnapshot.data == true) {
                // Profile exists, get user data and go to home page
                return FutureBuilder(
                  future: ref
                      .read(userRepositoryProvider)
                      .getUserById(authState.uid!),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (userSnapshot.hasData && userSnapshot.data != null) {
                      final user = userSnapshot.data!;

                      // CRITICAL: Check if user changed, invalidate old cached providers
                      final bool userChanged =
                          _currentUserId != null && _currentUserId != user.uid;
                      if (userChanged) {
                        // User switched accounts - invalidate all family providers with old userId
                        try {
                          ref.invalidate(notificationsViewModelProvider);
                          ref.invalidate(heartRateStreamProvider);
                          ref.invalidate(spo2StreamProvider);
                          ref.invalidate(hrvStreamProvider);
                          ref.invalidate(sleepSessionsStreamProvider);
                          ref.invalidate(latestHealthAlertProvider);
                          ref.invalidate(healthAlertsProvider);
                        } catch (_) {}
                        // Cancel old session subscription
                        _sessionSubscription?.cancel();
                      }

                      _currentUserId = user.uid;

                      // Start session monitoring for single-device login enforcement
                      _sessionSubscription
                          ?.cancel(); // Cancel existing before creating new
                      _sessionSubscription =
                          SessionService.watchSessionValidity(user.uid).listen(
                            (isValid) {
                              // Only show kicked dialog if still authenticated
                              // (to prevent showing during logout)
                              if (!isValid && mounted) {
                                try {
                                  final currentAuthState = ref.read(
                                    authProvider,
                                  );
                                  if (currentAuthState.isAuthenticated) {
                                    // Session kicked by another device
                                    _showKickedDialog();
                                  }
                                } catch (e) {
                                  // Widget disposed, ignore
                                }
                              }
                            },
                            onError: (error) {
                              // Ignore permission errors during logout
                            },
                            cancelOnError: false,
                          );

                      // Enable passive listener and AI monitoring ONLY for patients
                      // Doctors don't need health tracking
                      if (user.isPatient) {
                        // Enable passive listener (handles data collection)
                        ref.read(passiveListenerViewModelProvider).enable();

                        // Enable AI health monitoring
                        // Reuses PassiveListener's 15-min WorkManager for data collection
                        // AI checks run every 6 hours after data sync
                        startHealthMonitoring(user.uid);
                      }

                      // Start local notifications listening after first frame
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        // Start background notification service only
                        ref
                            .read(localNotificationsViewModelProvider)
                            .startForUser(user.uid);
                        // Ensure tap listener for foreground service
                        ref
                            .read(foregroundServiceViewModelProvider)
                            .ensureTapListener();

                        // Start scheduled notification checker for medication reminders
                        ref
                            .read(scheduledNotificationServiceProvider)
                            .startPeriodicCheck();
                      });
                      return IncomingCallListener(
                        child: HomePage(userRole: user.role),
                      );
                    }

                    return const LoginScreen();
                  },
                );
              } else {
                // Profile doesn't exist, go to setup
                return UserSetupScreen(
                  uid: authState.uid!,
                  email: authState.email ?? '',
                );
              }
            },
          );
        },
      );
    }

    // Not authenticated - CLEANUP ALL LISTENERS AND PROVIDERS
    // Reset current user id
    _currentUserId = null;
    _sessionSubscription?.cancel();
    _sessionSubscription = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // CRITICAL: Stop all listeners and services to prevent leaking user data
      // Incoming call listener removed - using background service only

      try {
        // Disable passive listener
        ref.read(passiveListenerViewModelProvider).disable();
      } catch (_) {}

      try {
        // Stop local notifications and foreground service
        ref.read(localNotificationsViewModelProvider).stopAll();
      } catch (_) {}

      // IMPORTANT: Invalidate all family providers that may cache old user data
      try {
        ref.invalidate(notificationsViewModelProvider);
      } catch (_) {}

      try {
        ref.invalidate(heartRateStreamProvider);
      } catch (_) {}

      try {
        ref.invalidate(spo2StreamProvider);
      } catch (_) {}

      try {
        ref.invalidate(hrvStreamProvider);
      } catch (_) {}

      try {
        ref.invalidate(sleepSessionsStreamProvider);
      } catch (_) {}
    });
    return const LoginScreen();
  }
}
