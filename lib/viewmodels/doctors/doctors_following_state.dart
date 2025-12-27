import '../../data/models/doctor_model.dart';

class DoctorsFollowingState {
  final bool loading;
  final String? error;
  final List<DoctorModel> doctors;

  const DoctorsFollowingState({
    required this.loading,
    required this.error,
    required this.doctors,
  });

  const DoctorsFollowingState.initial()
    : loading = false,
      error = null,
      doctors = const [];

  DoctorsFollowingState copyWith({
    bool? loading,
    String? error,
    List<DoctorModel>? doctors,
  }) {
    return DoctorsFollowingState(
      loading: loading ?? this.loading,
      error: error,
      doctors: doctors ?? this.doctors,
    );
  }
}
