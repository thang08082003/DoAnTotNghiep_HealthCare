import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare/data/models/user_model.dart';
import 'package:healthcare/data/repositories/help_repository.dart';

import 'help_state.dart';

class HelpViewModel extends StateNotifier<HelpState> {
  final HelpRepository _repo;
  final UserRole role;

  HelpViewModel(this._repo, this.role) : super(const HelpState.initial()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final guide = await _repo.getGuideForRole(role);
      state = state.copyWith(loading: false, guide: guide);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final helpViewModelProvider =
    StateNotifierProvider.family<HelpViewModel, HelpState, UserRole>((
      ref,
      role,
    ) {
      final repo = HelpRepository();
      return HelpViewModel(repo, role);
    });
