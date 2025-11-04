import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../screens/login/login_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/user_setup/user_setup_screen.dart';
import '../screens/user_setup/disease_doctor_selection/disease_doctor_selection_screen.dart';
import '../screens/user_setup/doctor_specialty_selection/doctor_specialty_selection_screen.dart';
import '../screens/home/home_page.dart';
import '../viewmodels/notifications/local_notifications_view_model.dart';
import '../viewmodels/foreground/foreground_service_view_model.dart';
import '../viewmodels/incoming_call/incoming_call_view_model.dart';
import '../viewmodels/passive_listener/passive_listener_view_model.dart';

class AppRouter {
  // Route names
  static const String login = '/login';
  static const String register = '/register';
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

      // case dashboard:
      //   return MaterialPageRoute(
      //     builder: (_) => const HomePage(),
      //     settings: settings,
      //   );

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

  // static void pushDashboard(BuildContext context, {required UserRole userRole}) {
  //   Navigator.of(context).pushNamedAndRemoveUntil(
  //     dashboard,
  //     (route) => false,
  //     arguments: userRole,
  //   );
  // }
}

// Auth Wrapper với logic điều hướng
class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper>
    with WidgetsBindingObserver {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
                      _currentUserId = user.uid;
                      // Enable passive listener
                      ref.read(passiveListenerViewModelProvider).enable();
                      // Start local notifications listening after first frame
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final lnsVm = ref.read(
                          localNotificationsViewModelProvider,
                        );
                        lnsVm
                            .initialize()
                            .then((_) => lnsVm.startForUser(user.uid))
                            .catchError((_) {});
                        // Ensure tap listener for foreground service
                        ref
                            .read(foregroundServiceViewModelProvider)
                            .ensureTapListener();
                        // Start incoming call listener
                        ref
                            .read(incomingCallViewModelProvider)
                            .startForUser(user.uid);
                      });
                      return HomePage(userRole: user.role);
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

    // Not authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Stop incoming call listener if any
      ref.read(incomingCallViewModelProvider).stop();
      // Disable passive listener when logging out
      ref.read(passiveListenerViewModelProvider).disable();
      // Stop local notifications and foreground service when logging out
      ref.read(localNotificationsViewModelProvider).stopAll();
    });
    return const LoginScreen();
  }
}
