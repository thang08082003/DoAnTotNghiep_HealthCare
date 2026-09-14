import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/foreground_service_repository.dart';

class ForegroundServiceViewModel {
  final ForegroundServiceRepository _repo = ForegroundServiceRepository();

  Future<void> start(String userId) => _repo.start(userId);
  Future<void> stop() => _repo.stop();
  void ensureTapListener() => _repo.ensureTapListener();
}

final foregroundServiceViewModelProvider = Provider<ForegroundServiceViewModel>(
  (ref) {
    return ForegroundServiceViewModel();
  },
);
