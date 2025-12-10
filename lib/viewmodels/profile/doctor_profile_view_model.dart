import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/doctor_model.dart';
import '../../data/repositories/doctor_profile_repository.dart';
import 'doctor_profile_state.dart';

class DoctorProfileViewModel extends StateNotifier<DoctorProfileState> {
  final DoctorProfileRepository _repo;
  final String uid;
  DoctorProfileViewModel(this._repo, this.uid)
    : super(const DoctorProfileState.initial()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final doctor = await _repo.getDoctor(uid);
      final raw = await _repo.getRaw(uid);
      final yearsRaw = raw != null ? raw['yearsExperience'] : null;
      final years = yearsRaw is int
          ? yearsRaw
          : int.tryParse((yearsRaw ?? '').toString());
      final descRaw = raw != null ? raw['description'] : null;
      final desc = (descRaw ?? '').toString();
      state = state.copyWith(
        loading: false,
        name: doctor?.name ?? '',
        specialty: doctor?.specialty,
        yearsExperience: years,
        description: desc,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setName(String name) => state = state.copyWith(name: name);
  void setSpecialty(Specialty? s) => state = state.copyWith(specialty: s);
  void setYears(String text) {
    if (text.trim().isEmpty) {
      state = state.copyWith(yearsExperience: null);
    } else {
      state = state.copyWith(yearsExperience: int.tryParse(text.trim()));
    }
  }

  void setDescription(String desc) => state = state.copyWith(description: desc);

  Future<void> save() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.updateDoctorProfile(
        uid,
        name: state.name.trim(),
        specialty: state.specialty,
        yearsExperience: state.yearsExperience,
        description: state.description,
      );
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> updatePhone(String? digits) async {
    await _repo.updatePhone(uid, digits);
  }

  Future<void> updateYearsExperience(int years) async {
    await _repo.updateYearsExperience(uid, years);
  }

  Future<void> updateDescription(String? description) async {
    await _repo.updateDescription(uid, description);
  }
}

final doctorProfileViewModelProvider =
    StateNotifierProvider.family<
      DoctorProfileViewModel,
      DoctorProfileState,
      String
    >((ref, uid) {
      final repo = DoctorProfileRepository();
      final vm = DoctorProfileViewModel(repo, uid);
      return vm;
    });
