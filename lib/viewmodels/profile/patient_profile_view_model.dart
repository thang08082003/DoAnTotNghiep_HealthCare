import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/patient_profile_repository.dart';

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

class PatientProfileViewModel extends StateNotifier<PatientProfileState> {
  final PatientProfileRepository _repo;
  final String uid;
  PatientProfileViewModel(this._repo, this.uid)
    : super(const PatientProfileState.initial()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final raw = await _repo.getRaw(uid);
      final phone = (raw?['phone'] as String?) ?? '';
      final ageText = raw?['age'] is int
          ? (raw?['age'] as int).toString()
          : ((raw?['age'] as String?) ?? '');
      final genderRaw = (raw?['gender'] as String?) ?? '';
      final gender = genderRaw.trim().isNotEmpty ? genderRaw : 'Khác';
      final history = (raw?['medicalHistory'] is String)
          ? (raw?['medicalHistory'] as String)
          : '';
      state = state.copyWith(
        loading: false,
        phone: phone,
        ageText: ageText,
        gender: gender,
        medicalHistory: history,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setPhone(String v) => state = state.copyWith(phone: v);
  void setAgeText(String v) => state = state.copyWith(ageText: v);
  void setGender(String v) => state = state.copyWith(gender: v);
  void setHistory(String v) => state = state.copyWith(medicalHistory: v);

  Future<void> save() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final trimmedAge = state.ageText.trim();
      final parsedAge = trimmedAge.isEmpty ? null : int.tryParse(trimmedAge);
      await _repo.updatePatientProfile(
        uid,
        phone: state.phone.trim(),
        age: parsedAge,
        gender: state.gender.trim(),
        medicalHistory: state.medicalHistory.trim(),
      );
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> updatePhone(String phone) async {
    try {
      await _repo.updatePhone(uid, phone);
    } catch (e) {
      // ignore; view handles feedback
    }
  }

  Future<void> updateAge(int? age) async {
    try {
      await _repo.updateAge(uid, age);
    } catch (e) {}
  }

  Future<void> updateMedicalHistory(String history) async {
    try {
      await _repo.updateMedicalHistory(uid, history);
    } catch (e) {}
  }

  Future<void> updateDiseaseFocus(String? focusValue) async {
    try {
      await _repo.updateDiseaseFocus(uid, focusValue);
    } catch (e) {}
  }
}

final patientProfileViewModelProvider =
    StateNotifierProvider.family<
      PatientProfileViewModel,
      PatientProfileState,
      String
    >((ref, uid) {
      final repo = PatientProfileRepository();
      return PatientProfileViewModel(repo, uid);
    });
