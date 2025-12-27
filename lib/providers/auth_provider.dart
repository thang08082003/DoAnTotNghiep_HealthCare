import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/auth_repository.dart';
import '../utilities/cleanup_service.dart';

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Auth State Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

// Auth State
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? uid;
  final String? email;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.uid,
    this.email,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? uid,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState()) {
    _checkAuthState();
  }

  void _checkAuthState() {
    _authRepository.authStateChanges.listen((user) {
      if (user != null) {
        state = state.copyWith(
          isAuthenticated: true,
          uid: user.uid,
          email: user.email,
          isLoading: false,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          uid: null,
          email: null,
          isLoading: false,
          errorMessage: null,
        );
      }
    });
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _authRepository.signInWithEmailAndPassword(email, password);
      // State will be updated through the stream listener
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> register(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _authRepository.registerWithEmailAndPassword(email, password);
      // State will be updated through the stream listener
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      // CRITICAL: Stop all listeners BEFORE signing out to prevent permission errors
      await CleanupService.stopAllListeners();

      // Stop health monitoring before logout

      // Cancel session monitoring before signing out
      // (This will be handled in AuthWrapper when not authenticated state triggers)

      // Sign out from Firebase
      await _authRepository.signOut();

      // IMPORTANT: Clear all state to prevent old user data leaking
      state = const AuthState(
        isLoading: false,
        isAuthenticated: false,
        uid: null,
        email: null,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
