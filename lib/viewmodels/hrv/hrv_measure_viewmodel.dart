import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/domain/hrv_stats.dart';
import '../../providers/user_provider.dart';
import '../../data/domain/measure_and_save_hrv_usecase.dart';

class HrvMeasureState {
  final bool initializing;
  final bool running;
  final bool saving;
  final double progress; // 0..1
  final HrvStats? stats;
  final String? error;

  const HrvMeasureState({
    this.initializing = false,
    this.running = false,
    this.saving = false,
    this.progress = 0.0,
    this.stats,
    this.error,
  });

  HrvMeasureState copyWith({
    bool? initializing,
    bool? running,
    bool? saving,
    double? progress,
    HrvStats? stats,
    String? error,
  }) => HrvMeasureState(
    initializing: initializing ?? this.initializing,
    running: running ?? this.running,
    saving: saving ?? this.saving,
    progress: progress ?? this.progress,
    stats: stats ?? this.stats,
    error: error,
  );
}

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
