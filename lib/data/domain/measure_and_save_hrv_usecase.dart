import '../domain/hrv_analyzer.dart';
import '../models/hrv_stats.dart';
import '../repositories/health_metrics_repository.dart';

/// Usecase to compute HRV stats from raw signal and persist them via repository
class MeasureAndSaveHrvUseCase {
  final HrvAnalyzer analyzer;
  final HealthMetricsRepository repository;

  MeasureAndSaveHrvUseCase({required this.analyzer, required this.repository});

  /// Compute and save HRV for [uid] using [signal] and [timestamps] (sec)
  Future<HrvStats> call({
    required String uid,
    required List<double> signal,
    required List<double> timestamps,
  }) async {
    final stats = analyzer.compute(signal, timestamps);
    await repository.saveManualHrv(
      uid,
      sdnn: stats.sdnn,
      rmssd: stats.rmssd,
      pnn50: stats.pnn50,
      hr: stats.hr,
      score: stats.score,
      level: stats.level,
    );
    return stats;
  }
}
