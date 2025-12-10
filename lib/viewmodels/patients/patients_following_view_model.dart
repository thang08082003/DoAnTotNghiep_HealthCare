import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/follow_request_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../providers/user_provider.dart';
import 'patients_following_state.dart';

class PatientsFollowingViewModel extends StateNotifier<PatientsFollowingState> {
  final FollowRequestRepository _followRepo;
  final UserRepository _userRepo;
  PatientsFollowingViewModel(this._followRepo, this._userRepo)
    : super(const PatientsFollowingState.initial());

  Future<void> loadPatientsForDoctor(String doctorId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final patientIds = await _followRepo.getAcceptedPatientIdsForDoctor(
        doctorId,
      );
      if (patientIds.isEmpty) {
        state = state.copyWith(loading: false, patients: const []);
        return;
      }
      final futures = patientIds.map((id) => _userRepo.getUserById(id));
      final results = await Future.wait(futures);
      final users = results.whereType<UserModel>().toList();
      state = state.copyWith(loading: false, patients: users);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final patientsFollowingViewModelProvider =
    StateNotifierProvider.family<
      PatientsFollowingViewModel,
      PatientsFollowingState,
      String
    >((ref, doctorId) {
      final followRepo = FollowRequestRepository();
      final userRepo = ref.read(userRepositoryProvider);
      final vm = PatientsFollowingViewModel(followRepo, userRepo);
      if (doctorId.isNotEmpty) {
        // ignore: unawaited_futures
        vm.loadPatientsForDoctor(doctorId);
      }
      return vm;
    });
