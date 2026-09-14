import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/follow_request_repository.dart';

class FollowRequestViewModel {
  final FollowRequestRepository _repo = FollowRequestRepository();

  Future<String?> getRequestStatus({
    required String patientId,
    required String doctorId,
  }) {
    return _repo.getRequestStatus(patientId: patientId, doctorId: doctorId);
  }
}

final followRequestViewModelProvider = Provider<FollowRequestViewModel>((ref) {
  return FollowRequestViewModel();
});
