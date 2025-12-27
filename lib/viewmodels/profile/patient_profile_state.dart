class PatientProfileState {
  final bool loading;
  final String? error;
  final String phone;
  final String ageText;
  final String gender;
  final String medicalHistory;

  const PatientProfileState({
    required this.loading,
    required this.error,
    required this.phone,
    required this.ageText,
    required this.gender,
    required this.medicalHistory,
  });

  const PatientProfileState.initial()
    : loading = true,
      error = null,
      phone = '',
      ageText = '',
      gender = 'Khác',
      medicalHistory = '';

  PatientProfileState copyWith({
    bool? loading,
    String? error,
    String? phone,
    String? ageText,
    String? gender,
    String? medicalHistory,
  }) {
    return PatientProfileState(
      loading: loading ?? this.loading,
      error: error,
      phone: phone ?? this.phone,
      ageText: ageText ?? this.ageText,
      gender: gender ?? this.gender,
      medicalHistory: medicalHistory ?? this.medicalHistory,
    );
  }
}
