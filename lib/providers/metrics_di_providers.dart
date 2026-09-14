import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/domain/metrics_usecase.dart';
import '../data/domain/hrv_analyzer.dart';
import '../data/domain/measure_and_save_hrv_usecase.dart';
import 'health_metrics_providers.dart';

/// Centralized DI wiring for metrics-related use cases and analyzers.
/// Keeps Riverpod out of the domain layer.

// Analyzer
final hrvAnalyzerProvider = Provider<HrvAnalyzer>((ref) => const HrvAnalyzer());

// Measure & Save HRV
final measureAndSaveHrvUseCaseProvider = Provider<MeasureAndSaveHrvUseCase>((
  ref,
) {
  final analyzer = ref.watch(hrvAnalyzerProvider);
  final repo = ref.watch(healthMetricsRepositoryProvider);
  return MeasureAndSaveHrvUseCase(analyzer: analyzer, repository: repo);
});

// Metrics aggregate use case (HR, SpO2, Sleep, HRV)
// Now reads all data from Firestore only; PassiveDrainWorker handles Health Connect sync
final metricsUsecaseProvider = Provider<MetricsUsecase>((ref) {
  final repo = ref.watch(healthMetricsRepositoryProvider);
  return MetricsUsecase(repo: repo);
});
