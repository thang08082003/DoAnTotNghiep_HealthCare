import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_metric_models.dart';

/// Low level Firestore access for health metrics.
class HealthMetricsService {
  final FirebaseFirestore _fs;
  HealthMetricsService({FirebaseFirestore? firestore})
    : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userCol(String uid, String sub) =>
      _fs.collection('users').doc(uid).collection(sub);

  // ---- Batch helpers ----
  Future<void> saveHeartRates(String uid, List<HeartRateSample> samples) async {
    if (samples.isEmpty) return;
    await _chunkedWrite(samples, (b, s) {
      b.set(
        _userCol(uid, 'heart_rate').doc(s.docId()),
        s.toMap(),
        SetOptions(merge: false),
      );
    });
  }

  Future<void> saveSpo2(String uid, List<Spo2Sample> samples) async {
    if (samples.isEmpty) return;
    await _chunkedWrite(samples, (b, s) {
      b.set(
        _userCol(uid, 'spo2').doc(s.docId()),
        s.toMap(),
        SetOptions(merge: false),
      );
    });
  }

  Future<void> saveHrv(String uid, List<HrvSample> samples) async {
    if (samples.isEmpty) return;
    await _chunkedWrite(samples, (b, s) {
      b.set(
        _userCol(uid, 'hrv').doc(s.docId()),
        s.toMap(),
        SetOptions(merge: false),
      );
    });
  }

  Future<void> saveSleepSessions(
    String uid,
    List<SleepSession> sessions,
  ) async {
    if (sessions.isEmpty) return;
    await _chunkedWrite(sessions, (b, s) {
      b.set(
        _userCol(uid, 'sleep_sessions').doc(s.docId()),
        s.toMap(),
        SetOptions(merge: false),
      );
    });
  }

  // Manual HRV measurement save (single point) - choose ts now if not provided.
  Future<void> saveManualHrv(
    String uid, {
    double? sdnn,
    double? rmssd,
    double? pnn50,
    double? hr,
    int? score,
    String? level,
    DateTime? ts,
  }) async {
    final sample = HrvSample(
      ts: ts ?? DateTime.now(),
      sdnn: sdnn,
      rmssd: rmssd,
      source: 'manual',
      pnn50: pnn50,
      hr: hr,
      score: score,
      level: level,
    );
    await saveHrv(uid, [sample]);
  }

  // ---- Streams ----
  Stream<List<HeartRateSample>> heartRateStream(
    String uid, {
    DateTime? from,
    int? limit,
  }) {
    Query<Map<String, dynamic>> q = _userCol(
      uid,
      'heart_rate',
    ).orderBy('ts', descending: true);
    if (from != null) {
      q = q.where(
        'ts',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from.toUtc()),
      );
    }
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map(
      (s) => s.docs.map((d) => HeartRateSample.fromFirestore(d)).toList(),
    );
  }

  Stream<List<Spo2Sample>> spo2Stream(
    String uid, {
    DateTime? from,
    int? limit,
  }) {
    Query<Map<String, dynamic>> q = _userCol(
      uid,
      'spo2',
    ).orderBy('ts', descending: true);
    if (from != null)
      q = q.where(
        'ts',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from.toUtc()),
      );
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map(
      (s) => s.docs.map((d) => Spo2Sample.fromFirestore(d)).toList(),
    );
  }

  Stream<List<HrvSample>> hrvStream(String uid, {DateTime? from, int? limit}) {
    Query<Map<String, dynamic>> q = _userCol(
      uid,
      'hrv',
    ).orderBy('ts', descending: true);
    if (from != null)
      q = q.where(
        'ts',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from.toUtc()),
      );
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map(
      (s) => s.docs.map((d) => HrvSample.fromFirestore(d)).toList(),
    );
  }

  Stream<List<SleepSession>> sleepStream(
    String uid, {
    DateTime? from,
    int? limit,
  }) {
    Query<Map<String, dynamic>> q = _userCol(
      uid,
      'sleep_sessions',
    ).orderBy('start', descending: true);
    if (from != null)
      q = q.where(
        'start',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from.toUtc()),
      );
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map(
      (s) => s.docs.map((d) => SleepSession.fromFirestore(d)).toList(),
    );
  }

  // ---- One-off fetch for overview (client aggregate) ----
  Future<PatientMetricsOverview> overview(
    String uid, {
    Duration range = const Duration(days: 7),
  }) async {
    final end = DateTime.now();
    final start = end.subtract(range);
    final tsStart = Timestamp.fromDate(start.toUtc());
    final hrDocs = await _userCol(
      uid,
      'heart_rate',
    ).where('ts', isGreaterThanOrEqualTo: tsStart).get();
    final spo2Docs = await _userCol(
      uid,
      'spo2',
    ).where('ts', isGreaterThanOrEqualTo: tsStart).get();
    final hrvDocs = await _userCol(
      uid,
      'hrv',
    ).where('ts', isGreaterThanOrEqualTo: tsStart).get();
    final sleepDocs = await _userCol(
      uid,
      'sleep_sessions',
    ).where('start', isGreaterThanOrEqualTo: tsStart).get();

    double? avgHr;
    if (hrDocs.docs.isNotEmpty) {
      final vals = hrDocs.docs
          .map((d) => (d['bpm'] as num).toDouble())
          .toList();
      avgHr = vals.reduce((a, b) => a + b) / vals.length;
    }
    double? avgSpo2;
    if (spo2Docs.docs.isNotEmpty) {
      final vals = spo2Docs.docs
          .map((d) => (d['percentage'] as num).toDouble())
          .toList();
      avgSpo2 = vals.reduce((a, b) => a + b) / vals.length;
    }
    double? avgSdnn;
    double? avgRmssd;
    if (hrvDocs.docs.isNotEmpty) {
      final sdnnVals = <double>[];
      final rmssdVals = <double>[];
      for (final d in hrvDocs.docs) {
        final m = d.data();
        final sd = (m['sdnn'] as num?)?.toDouble();
        final rm = (m['rmssd'] as num?)?.toDouble();
        if (sd != null) sdnnVals.add(sd);
        if (rm != null) rmssdVals.add(rm);
      }
      if (sdnnVals.isNotEmpty)
        avgSdnn = sdnnVals.reduce((a, b) => a + b) / sdnnVals.length;
      if (rmssdVals.isNotEmpty)
        avgRmssd = rmssdVals.reduce((a, b) => a + b) / rmssdVals.length;
    }
    Duration totalSleep = Duration.zero;
    for (final d in sleepDocs.docs) {
      final m = d.data();
      final mins = m['durationMinutes'] as int?;
      if (mins != null) totalSleep += Duration(minutes: mins);
    }

    return PatientMetricsOverview(
      avgHr: avgHr,
      avgSpo2: avgSpo2,
      avgHrvSdnn: avgSdnn,
      avgHrvRmssd: avgRmssd,
      totalSleep: totalSleep,
      heartRateSamples: hrDocs.size,
      spo2Samples: spo2Docs.size,
      hrvSamples: hrvDocs.size,
      sleepSessions: sleepDocs.size,
    );
  }

  // Generic chunked batch writer (Firestore limit = 500 writes per batch)
  Future<void> _chunkedWrite<T>(
    List<T> items,
    void Function(WriteBatch b, T item) add,
  ) async {
    const int maxPerBatch = 450; // keep some headroom
    for (int i = 0; i < items.length; i += maxPerBatch) {
      final batch = _fs.batch();
      final slice = items.sublist(
        i,
        i + maxPerBatch > items.length ? items.length : i + maxPerBatch,
      );
      for (final s in slice) {
        add(batch, s);
      }
      await batch.commit();
    }
  }
}
