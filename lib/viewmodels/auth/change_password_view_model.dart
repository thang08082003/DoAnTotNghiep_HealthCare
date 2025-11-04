import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordState {
  final bool isLoading;
  final bool isEmailVerified;
  final String? email;
  final String? errorMessage;
  final String? successMessage;
  final bool emailVerificationSent;

  const ChangePasswordState({
    this.isLoading = false,
    this.isEmailVerified = false,
    this.email,
    this.errorMessage,
    this.successMessage,
    this.emailVerificationSent = false,
  });

  ChangePasswordState copyWith({
    bool? isLoading,
    bool? isEmailVerified,
    String? email,
    String? errorMessage,
    String? successMessage,
    bool? emailVerificationSent,
  }) {
    return ChangePasswordState(
      isLoading: isLoading ?? this.isLoading,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      email: email ?? this.email,
      errorMessage: errorMessage,
      successMessage: successMessage,
      emailVerificationSent:
          emailVerificationSent ?? this.emailVerificationSent,
    );
  }
}

class ChangePasswordViewModel extends StateNotifier<ChangePasswordState> {
  final AuthRepository _repo;
  ChangePasswordViewModel(this._repo)
    : super(
        ChangePasswordState(
          isEmailVerified: _repo.isEmailVerified,
          email: _repo.currentEmail,
        ),
      );

  Future<void> sendVerificationEmail() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await _repo.sendEmailVerification();
      state = state.copyWith(
        isLoading: false,
        emailVerificationSent: true,
        successMessage:
            'Đã gửi email xác thực. Vui lòng kiểm tra hộp thư.\nSau khi xác thực, hãy bấm "Kiểm tra trạng thái".',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refreshEmailVerified() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await _repo.reloadUser();
      state = state.copyWith(
        isLoading: false,
        isEmailVerified: _repo.isEmailVerified,
        email: _repo.currentEmail,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (!state.isEmailVerified) {
      state = state.copyWith(
        errorMessage: 'Vui lòng xác thực email trước khi đổi mật khẩu.',
      );
      return;
    }
    if (newPassword != confirmPassword) {
      state = state.copyWith(
        errorMessage: 'Mật khẩu mới và xác nhận không khớp.',
      );
      return;
    }
    if (newPassword.length < 6) {
      state = state.copyWith(
        errorMessage: 'Mật khẩu mới phải có ít nhất 6 ký tự.',
      );
      return;
    }

    final email = state.email;
    if (email == null || email.isEmpty) {
      state = state.copyWith(errorMessage: 'Không tìm thấy email người dùng.');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      // Firebase yêu cầu re-auth gần đây trước khi đổi mật khẩu
      await _repo.reauthenticateWithPassword(email, currentPassword);
      await _repo.updatePassword(newPassword);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Đổi mật khẩu thành công.',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}

final changePasswordViewModelProvider =
    StateNotifierProvider.autoDispose<
      ChangePasswordViewModel,
      ChangePasswordState
    >((ref) {
      final repo = ref.watch(authRepositoryProvider);
      return ChangePasswordViewModel(repo);
    });
