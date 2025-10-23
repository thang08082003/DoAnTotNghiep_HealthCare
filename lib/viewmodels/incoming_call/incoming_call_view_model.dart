import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/incoming_call_repository.dart';

class IncomingCallViewModel {
  final IncomingCallRepository _repo = IncomingCallRepository();

  void startForUser(String userId) => _repo.start(userId);
  void stop() => _repo.stop();
}

final incomingCallViewModelProvider = Provider<IncomingCallViewModel>((ref) {
  return IncomingCallViewModel();
});
