import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/domain/metrics_usecase.dart';
import '../data/domain/hrv_analyzer.dart';
import '../data/domain/measure_and_save_hrv_usecase.dart';
import '../data/services/health_connect_service.dart';
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
final metricsUsecaseProvider = Provider<MetricsUsecase>((ref) {
  final repo = ref.watch(healthMetricsRepositoryProvider);
  final gfit = GoogleFitService();
  return MetricsUsecase(repo: repo, gfit: gfit);
});
