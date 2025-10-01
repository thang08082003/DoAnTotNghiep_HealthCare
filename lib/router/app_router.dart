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
  }) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      diseaseDoctorSelection,
      (route) => false,
      arguments: {
        'patientId': patientId,
        'patientName': patientName,
        'patientEmail': patientEmail,
      },
    );
  }

  static void pushDoctorSpecialtySelection(
    BuildContext context, {
    required String doctorId,
    required String doctorName,
    required String doctorEmail,
  }) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      doctorSpecialtySelection,
      (route) => false,
      arguments: {
        'doctorId': doctorId,
        'doctorName': doctorName,
        'doctorEmail': doctorEmail,
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
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return const LoginScreen();
  }
}
