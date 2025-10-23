import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
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

class AuthViewModel extends StateNotifier<AuthViewState> {
  final Ref _ref;
  AuthViewModel(this._ref) : super(const AuthViewState.initial());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(authProvider.notifier).login(email, password);
      final auth = _ref.read(authProvider);
      if (auth.errorMessage != null && auth.errorMessage!.isNotEmpty) {
        state = state.copyWith(isLoading: false, error: auth.errorMessage);
        _ref.read(authProvider.notifier).clearError();
        return;
      }
      if (auth.isAuthenticated && auth.uid != null) {
        final uid = auth.uid!;
        final exists = await _ref.read(userRepositoryProvider).userExists(uid);
        if (!exists) {
          state = state.copyWith(
            isLoading: false,
            isAuthenticated: true,
            needsSetup: true,
            uid: uid,
            email: auth.email,
          );
          return;
        }
        final user = await _ref.read(userRepositoryProvider).getUserById(uid);
        final role = user?.role ?? UserRole.patient;
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          needsSetup: false,
          role: role,
          uid: uid,
          email: auth.email,
        );
        return;
      }
      // Fallback: not authenticated
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AuthViewState>((ref) {
      return AuthViewModel(ref);
    });
