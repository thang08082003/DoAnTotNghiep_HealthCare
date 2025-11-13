import '../models/health_metric_models.dart';
import '../services/health_metrics_service.dart';

class HealthMetricsRepository {
  final HealthMetricsService _service;
  HealthMetricsRepository(this._service);

  // Manual HRV external call
  Future<void> saveManualHrv(
    String uid, {
    double? sdnn,
    double? rmssd,
    double? pnn50,
    double? hr,
    int? score,
    String? level,
    DateTime? ts,
  }) => _service.saveManualHrv(
    uid,
    sdnn: sdnn,
    rmssd: rmssd,
    pnn50: pnn50,
    hr: hr,
    score: score,
    level: level,
    ts: ts,
  );

  // Streams pass-through
  Stream<List<HeartRateSample>> heartRateStream(
    String uid, {
    DateTime? from,
    int? limit,
  }) => _service.heartRateStream(uid, from: from, limit: limit);
  Stream<List<Spo2Sample>> spo2Stream(
    String uid, {
    DateTime? from,
    int? limit,
  }) => _service.spo2Stream(uid, from: from, limit: limit);
  Stream<List<HrvSample>> hrvStream(String uid, {DateTime? from, int? limit}) =>
      _service.hrvStream(uid, from: from, limit: limit);
  Stream<List<SleepSession>> sleepStream(
    String uid, {
    DateTime? from,
    int? limit,
  }) => _service.sleepStream(uid, from: from, limit: limit);

  Future<PatientMetricsOverview> overview(
    String uid, {
    Duration range = const Duration(days: 7),
  }) => _service.overview(uid, range: range);
}

class SyncResult {
  final int heartRate;
  final int spo2;
  final int hrv;
  final int sleep;
  final bool granted;
  const SyncResult({
    required this.heartRate,
    required this.spo2,
    required this.hrv,
    required this.sleep,
    required this.granted,
  });
}
