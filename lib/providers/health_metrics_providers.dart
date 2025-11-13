import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/health_metrics_repository.dart';
import '../data/services/health_metrics_service.dart';
import '../data/services/health_connect_service.dart';
import '../data/models/health_metric_models.dart';
import 'user_provider.dart';

final healthMetricsRepositoryProvider = Provider<HealthMetricsRepository>((
  ref,
) {
  return HealthMetricsRepository(HealthMetricsService(), GoogleFitService());
});

// Auto sync last 24h when user loaded (one-shot per session)
// Only syncs for patients, not doctors (doctors view patient data from Firestore)
final _metricsSyncOnceProvider = FutureProvider<void>((ref) async {
  // Use the .future accessor on the FutureProvider itself
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return;

  // Only sync for patient role - doctors don't need Health Connect sync
  if (!user.isPatient) return;

  final repo = ref.watch(healthMetricsRepositoryProvider);
  if (_SyncGuard.syncedForUid.contains(user.uid)) return;
  try {
    await repo.syncLast24h(user.uid);
  } catch (_) {
    // swallow errors; UI still can show cached data
  }
  _SyncGuard.syncedForUid.add(user.uid);
});

class _SyncGuard {
  static final Set<String> syncedForUid = <String>{};
}

// Manual sync provider - allows patients to trigger sync on demand
final manualSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null || !user.isPatient) return;

  final repo = ref.watch(healthMetricsRepositoryProvider);
  await repo.syncLast24h(user.uid);
});

// Streams (latest N)
final heartRateStreamProvider =
    StreamProvider.family<List<HeartRateSample>, String>((ref, uid) {
      ref.watch(_metricsSyncOnceProvider); // ensure sync triggered
      return ref
          .watch(healthMetricsRepositoryProvider)
          .heartRateStream(uid, limit: 100);
    });
final spo2StreamProvider = StreamProvider.family<List<Spo2Sample>, String>((
  ref,
  uid,
) {
  ref.watch(_metricsSyncOnceProvider);
  return ref.watch(healthMetricsRepositoryProvider).spo2Stream(uid, limit: 100);
});
final hrvStreamProvider = StreamProvider.family<List<HrvSample>, String>((
  ref,
  uid,
) {
  ref.watch(_metricsSyncOnceProvider);
  return ref.watch(healthMetricsRepositoryProvider).hrvStream(uid, limit: 100);
});
final sleepSessionsStreamProvider =
    StreamProvider.family<List<SleepSession>, String>((ref, uid) {
      ref.watch(_metricsSyncOnceProvider);
      return ref
          .watch(healthMetricsRepositoryProvider)
          .sleepStream(uid, limit: 30);
    });

// Overview provider (computed on demand)
final metricsOverviewProvider =
    FutureProvider.family<PatientMetricsOverview, String>((ref, uid) async {
      ref.watch(_metricsSyncOnceProvider);
      return ref.watch(healthMetricsRepositoryProvider).overview(uid);
    });
