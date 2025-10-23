import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/passive_listener_repository.dart';

class PassiveListenerViewModel {
  final PassiveListenerRepository _repo = PassiveListenerRepository();

  void enable() => _repo.enable();
  void disable() => _repo.disable();
}

final passiveListenerViewModelProvider = Provider<PassiveListenerViewModel>((
  ref,
) {
  return PassiveListenerViewModel();
});
