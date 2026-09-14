import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';
import '../../providers/metrics_di_providers.dart';

import 'hrv_measure_state.dart';

class HrvMeasureViewModel extends StateNotifier<HrvMeasureState> {
  final Ref ref;

  HrvMeasureViewModel(this.ref) : super(const HrvMeasureState());

  void setProgress(double p) {
    state = state.copyWith(progress: p.clamp(0.0, 1.0));
  }

  Future<bool> measureAndSave({
    String? userId,
    required List<double> signal,
    required List<double> timestamps,
  }) async {
    state = state.copyWith(saving: true, error: null);
    try {
      String? uid = userId;
      if (uid == null) {
        final user = await ref.read(currentUserProvider.future);
        uid = user?.uid;
      }
      if (uid == null) {
        state = state.copyWith(
          saving: false,
          error: 'Không xác định người dùng',
        );
        return false;
      }
      final usecase = ref.read(measureAndSaveHrvUseCaseProvider);
      final stats = await usecase(
        uid: uid,
        signal: signal,
        timestamps: timestamps,
      );
      state = state.copyWith(saving: false, stats: stats);
      return true;
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
      return false;
    }
  }
}

final hrvMeasureViewModelProvider =
    StateNotifierProvider.autoDispose<HrvMeasureViewModel, HrvMeasureState>((
      ref,
    ) {
      return HrvMeasureViewModel(ref);
    });
