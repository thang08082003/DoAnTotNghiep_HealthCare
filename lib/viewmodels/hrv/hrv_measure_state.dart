import '../../data/models/hrv_stats.dart';

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
