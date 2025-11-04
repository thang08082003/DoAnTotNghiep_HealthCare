import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare/data/models/help_guide_model.dart';
import 'package:healthcare/data/models/user_model.dart';
import 'package:healthcare/data/repositories/help_repository.dart';

class HelpState {
  final bool loading;
  final String? error;
  final HelpGuide? guide;

  const HelpState({
    required this.loading,
    required this.error,
    required this.guide,
  });

  const HelpState.initial() : loading = true, error = null, guide = null;

  HelpState copyWith({bool? loading, String? error, HelpGuide? guide}) {
    return HelpState(
      loading: loading ?? this.loading,
      error: error,
      guide: guide ?? this.guide,
    );
  }
}

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
