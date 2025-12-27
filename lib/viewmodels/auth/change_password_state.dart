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
