import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/call_repository.dart';
import '../../data/models/call_session.dart';

class CallViewModel {
  final CallRepository _repo = CallRepository();

  Future<String> startOutgoingCall({
    required String callerId,
    required String calleeId,
    required String channelName,
  }) {
    return _repo.createOutgoingCall(
      callerId: callerId,
      calleeId: calleeId,
      channelName: channelName,
    );
  }

  Stream<CallSession?> watchCall(String callId) {
    return _repo.watchCall(callId);
  }
}

final callViewModelProvider = Provider<CallViewModel>((ref) {
  return CallViewModel();
});
