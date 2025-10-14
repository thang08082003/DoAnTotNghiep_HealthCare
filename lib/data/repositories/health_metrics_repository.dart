import 'package:health/health.dart';
import '../models/health_metric_models.dart';
import '../services/health_connect_service.dart';
import '../services/health_metrics_service.dart';

class HealthMetricsRepository {
  final HealthMetricsService _service;
  final GoogleFitService _gfit;
  HealthMetricsRepository(this._service, this._gfit);

  // Sync last 24h samples from Health Connect into Firestore
  Future<SyncResult> syncLast24h(String uid) async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(hours: 24));
    bool perm = false;
    try {
      perm = await _gfit.ensureConnected();
    } catch (_) {}
    if (!perm) {
      return const SyncResult(
        heartRate: 0,
        spo2: 0,
        hrv: 0,
        sleep: 0,
        granted: false,
      );
    }

    final hrPts = await _gfit.getDataFast(
      types: const [HealthDataType.HEART_RATE],
      start: start,
      end: end,
    );
    final spo2Pts = await _gfit.getDataFast(
      types: const [HealthDataType.BLOOD_OXYGEN],
      start: start,
      end: end,
    );
    // Only fetch RMSSD for HRV (plugin SDNN causes errors on some devices)
    List<HealthDataPoint> hrvRmssdPts = [];
    try {
      hrvRmssdPts = await _gfit.getDataFast(
        types: const [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
        start: start,
        end: end,
      );
    } catch (_) {}

    // Sleep sessions (pref session else asleep blocks within range of previous night?), for 24h just take sessions
    final sleepPts = await _gfit.getDataFast(
      types: const [HealthDataType.SLEEP_SESSION],
      start: start.subtract(
        const Duration(hours: 12),
      ), // widen start for overnight
      end: end,
    );

    // Map conversions
    final hrSamples = hrPts
        .map((p) {
          final v = p.value;
          if (v is NumericHealthValue) {
            final bpm = v.numericValue.toDouble();
            if (bpm > 0) {
              return HeartRateSample(
                ts: p.dateFrom,
                bpm: bpm,
                source: 'health_connect',
              );
            }
          }
          return null;
        })
        .whereType<HeartRateSample>()
        .toList();

    final spo2Samples = spo2Pts
        .map((p) {
          final v = p.value;
          if (v is NumericHealthValue) {
            final pct = v.numericValue.toDouble();
            if (pct > 0 && pct <= 100) {
              return Spo2Sample(
                ts: p.dateFrom,
                percentage: pct,
                source: 'health_connect',
              );
            }
          }
          return null;
        })
        .whereType<Spo2Sample>()
        .toList();

    final hrvSamples = <HrvSample>[];
    for (final p in hrvRmssdPts) {
      final v = p.value;
      if (v is NumericHealthValue) {
        final val = v.numericValue.toDouble();
        if (val > 0) {
          hrvSamples.add(
            HrvSample(ts: p.dateFrom, rmssd: val, source: 'health_connect'),
          );
        }
      }
    }

    // Sleep sessions -> SleepSession objects
    final sleepSessions = <SleepSession>[];
    for (final p in sleepPts) {
      final dur = p.dateTo.difference(p.dateFrom);
      if (dur.isNegative || dur.inMinutes <= 0) continue;
      sleepSessions.add(
        SleepSession(
          start: p.dateFrom,
          end: p.dateTo,
          durationMinutes: dur.inMinutes,
          source: 'health_connect',
          stages: null,
        ),
      );
    }

    // Persist
    await _service.saveHeartRates(uid, hrSamples);
    await _service.saveSpo2(uid, spo2Samples);
    await _service.saveHrv(uid, hrvSamples);
    await _service.saveSleepSessions(uid, sleepSessions);

    return SyncResult(
      heartRate: hrSamples.length,
      spo2: spo2Samples.length,
      hrv: hrvSamples.length,
      sleep: sleepSessions.length,
      granted: true,
    );
  }

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
