import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../data/models/user_model.dart';
import '../../data/services/session_service.dart';
import 'auth_state.dart';

class AuthViewModel extends StateNotifier<AuthViewState> {
  final Ref _ref;
  AuthViewModel(this._ref) : super(const AuthViewState.initial());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Call repository directly to avoid race with auth stream when re-login
      final repo = _ref.read(authRepositoryProvider);
      final cred = await repo.signInWithEmailAndPassword(email, password);
      final user = cred?.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          error: 'Đăng nhập thất bại',
        );
        return;
      }

      final uid = user.uid;
      final exists = await _ref.read(userRepositoryProvider).userExists(uid);
      if (!exists) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          needsSetup: true,
          uid: uid,
          email: user.email,
        );
        return;
      }

      final profile = await _ref.read(userRepositoryProvider).getUserById(uid);
      final role = profile?.role ?? UserRole.patient;

      // Create session for single-device login enforcement
      await SessionService.createSession(uid);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        needsSetup: false,
        role: role,
        uid: uid,
        email: user.email,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: e.toString(),
      );
    }
  }

  Future<void> register(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Register via repository to get immediate credential without relying on auth stream timing
      final repo = _ref.read(authRepositoryProvider);
      final cred = await repo.registerWithEmailAndPassword(email, password);
      final user = cred?.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          error: 'Đăng ký thất bại',
        );
        return;
      }

      // Create session immediately for new user to prevent "kicked" dialog
      await SessionService.createSession(user.uid);

      // Newly registered users won't have a profile yet -> needsSetup = true
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        needsSetup: true,
        uid: user.uid,
        email: user.email,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: e.toString(),
      );
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
