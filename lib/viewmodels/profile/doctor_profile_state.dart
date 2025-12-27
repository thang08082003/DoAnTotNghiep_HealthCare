import '../../data/models/doctor_model.dart';

class DoctorProfileState {
  final bool loading;
  final String? error;
  final String name;
  final Specialty? specialty;
  final int? yearsExperience;
  final String description;

  const DoctorProfileState({
    required this.loading,
    required this.error,
    required this.name,
    required this.specialty,
    required this.yearsExperience,
    required this.description,
  });

  const DoctorProfileState.initial()
    : loading = true,
      error = null,
      name = '',
      specialty = null,
      yearsExperience = null,
      description = '';

  DoctorProfileState copyWith({
    bool? loading,
    String? error,
    String? name,
    Specialty? specialty,
    bool clearSpecialty = false,
    int? yearsExperience,
    bool clearYears = false,
    String? description,
  }) {
    return DoctorProfileState(
      loading: loading ?? this.loading,
      error: error,
      name: name ?? this.name,
      specialty: clearSpecialty ? null : (specialty ?? this.specialty),
      yearsExperience: clearYears
          ? null
          : (yearsExperience ?? this.yearsExperience),
      description: description ?? this.description,
    );
  }
}
