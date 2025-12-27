import '../../data/models/user_model.dart';

class AuthViewState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final bool needsSetup;
  final UserRole? role;
  final String? uid;
  final String? email;

  const AuthViewState({
    required this.isLoading,
    required this.isAuthenticated,
    required this.error,
    required this.needsSetup,
    required this.role,
    required this.uid,
    required this.email,
  });

  const AuthViewState.initial()
    : isLoading = false,
      isAuthenticated = false,
      error = null,
      needsSetup = false,
      role = null,
      uid = null,
      email = null;

  AuthViewState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    bool? needsSetup,
    UserRole? role,
    String? uid,
    String? email,
    bool clearError = false,
  }) {
    return AuthViewState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: clearError ? null : (error ?? this.error),
      needsSetup: needsSetup ?? this.needsSetup,
      role: role ?? this.role,
      uid: uid ?? this.uid,
      email: email ?? this.email,
    );
  }
}
