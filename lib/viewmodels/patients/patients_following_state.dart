import '../../data/models/user_model.dart';

class PatientsFollowingState {
  final bool loading;
  final String? error;
  final List<UserModel> patients;

  const PatientsFollowingState({
    required this.loading,
    required this.error,
    required this.patients,
  });

  const PatientsFollowingState.initial()
    : loading = false,
      error = null,
      patients = const [];

  PatientsFollowingState copyWith({
    bool? loading,
    String? error,
    List<UserModel>? patients,
  }) {
    return PatientsFollowingState(
      loading: loading ?? this.loading,
      error: error,
      patients: patients ?? this.patients,
    );
  }
}
