import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/health_metrics_repository.dart';
import '../data/services/health_metrics_service.dart';
import '../data/models/health_metric_models.dart';

final healthMetricsRepositoryProvider = Provider<HealthMetricsRepository>((
  ref,
) {
  return HealthMetricsRepository(HealthMetricsService());
});

// Streams (latest N)
// NOTE: Auto-sync has been disabled. Users must manually sync via "Đồng bộ ngay" button
final heartRateStreamProvider =
    StreamProvider.family<List<HeartRateSample>, String>((ref, uid) {
      return ref
          .watch(healthMetricsRepositoryProvider)
          .heartRateStream(uid, limit: 100);
    });
final spo2StreamProvider = StreamProvider.family<List<Spo2Sample>, String>((
  ref,
  uid,
) {
  return ref.watch(healthMetricsRepositoryProvider).spo2Stream(uid, limit: 100);
});
final hrvStreamProvider = StreamProvider.family<List<HrvSample>, String>((
  ref,
  uid,
) {
  return ref.watch(healthMetricsRepositoryProvider).hrvStream(uid, limit: 100);
});
final sleepSessionsStreamProvider =
    StreamProvider.family<List<SleepSession>, String>((ref, uid) {
      return ref
          .watch(healthMetricsRepositoryProvider)
          .sleepStream(uid, limit: 30);
    });

// Overview provider (computed on demand)
final metricsOverviewProvider =
    FutureProvider.family<PatientMetricsOverview, String>((ref, uid) async {
      return ref.watch(healthMetricsRepositoryProvider).overview(uid);
    });
