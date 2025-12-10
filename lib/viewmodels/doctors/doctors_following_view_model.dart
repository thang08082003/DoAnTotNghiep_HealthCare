import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/doctor_model.dart';
import '../../data/repositories/follow_request_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../providers/user_provider.dart';
import 'doctors_following_state.dart';

class DoctorsFollowingViewModel extends StateNotifier<DoctorsFollowingState> {
  final FollowRequestRepository _followRepo;
  final UserRepository _userRepo;
  DoctorsFollowingViewModel(this._followRepo, this._userRepo)
    : super(const DoctorsFollowingState.initial());

  Future<void> loadDoctorsForPatient(String patientId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final doctorIds = await _followRepo.getAcceptedDoctorIdsForPatient(
        patientId,
      );
      if (doctorIds.isEmpty) {
        state = state.copyWith(loading: false, doctors: const []);
        return;
      }
      final futures = doctorIds.map((id) => _userRepo.getUserById(id));
      final results = await Future.wait(futures);
      final doctors = results.whereType<DoctorModel>().toList();
      state = state.copyWith(loading: false, doctors: doctors);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final doctorsFollowingViewModelProvider =
    StateNotifierProvider.family<
      DoctorsFollowingViewModel,
      DoctorsFollowingState,
      String
    >((ref, patientId) {
      final followRepo = FollowRequestRepository();
      final userRepo = ref.read(userRepositoryProvider);
      final vm = DoctorsFollowingViewModel(followRepo, userRepo);
      // kick off load
      if (patientId.isNotEmpty) {
        // ignore: unawaited_futures
        vm.loadDoctorsForPatient(patientId);
      }
      return vm;
    });
