import 'package:cloud_firestore/cloud_firestore.dart';

// Base helpers
DateTime _fromTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int)
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
  throw ArgumentError('Unsupported timestamp value: $v');
}

int _epochMsUtc(DateTime dt) => dt.toUtc().millisecondsSinceEpoch;

// Heart Rate
class HeartRateSample {
  final DateTime ts; // timestamp of sample
  final double bpm;
  final String? source;
  // Passive sync adds createdAt/createAt: the upload time on server
  final DateTime? createdAt;

  HeartRateSample({
    required this.ts,
    required this.bpm,
    this.source,
    this.createdAt,
  });

  factory HeartRateSample.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    // Support both active and passive payloads.
    // Passive adds createdAt (or createAt) as an extra server timestamp.
    final dynamic createdAtRaw = data['createdAt'] ?? data['createAt'];
    return HeartRateSample(
      ts: _fromTs(data['ts']),
      bpm: (data['bpm'] as num).toDouble(),
      source: data['source'] as String?,
      createdAt: createdAtRaw != null ? _fromTs(createdAtRaw) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'ts': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(ts)),
    'bpm': bpm,
    if (source != null) 'source': source,
    // We don't set createdAt here for active writes; server-side writes may populate it.
    if (createdAt != null)
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(
        _epochMsUtc(createdAt!),
      ),
  };

  String docId() => _epochMsUtc(ts).toString();
}

// SpO2
class Spo2Sample {
  final DateTime ts;
  final double percentage; // 0-100
  final String? source;
  // Passive sync adds createdAt/createAt and may use 'pct' instead of 'percentage'
  final DateTime? createdAt;

  Spo2Sample({
    required this.ts,
    required this.percentage,
    this.source,
    this.createdAt,
  });

  factory Spo2Sample.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Accept both field names: 'percentage' (active) and 'pct' (passive)
    final pctVal = data.containsKey('percentage')
        ? data['percentage']
        : data['pct'];
    final dynamic createdAtRaw = data['createdAt'] ?? data['createAt'];
    return Spo2Sample(
      ts: _fromTs(data['ts']),
      percentage: (pctVal as num).toDouble(),
      source: data['source'] as String?,
      createdAt: createdAtRaw != null ? _fromTs(createdAtRaw) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'ts': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(ts)),
    'percentage': percentage,
    if (source != null) 'source': source,
    if (createdAt != null)
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(
        _epochMsUtc(createdAt!),
      ),
  };

  String docId() => _epochMsUtc(ts).toString();
}

// HRV
class HrvSample {
  final DateTime ts;
  final double? rmssd;
  final double? sdnn;
  final String? source;
  final double? pnn50; // percentage
  final double? hr; // bpm measured during HRV
  final int? score; // computed HRV score
  final String? level; // qualitative level

  HrvSample({
    required this.ts,
    this.rmssd,
    this.sdnn,
    this.source,
    this.pnn50,
    this.hr,
    this.score,
    this.level,
  });

  factory HrvSample.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return HrvSample(
      ts: _fromTs(data['ts']),
      rmssd: (data['rmssd'] as num?)?.toDouble(),
      sdnn: (data['sdnn'] as num?)?.toDouble(),
      source: data['source'] as String?,
      pnn50: (data['pnn50'] as num?)?.toDouble(),
      hr: (data['hr'] as num?)?.toDouble(),
      score: (data['score'] as num?)?.toInt(),
      level: data['level'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'ts': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(ts)),
    if (rmssd != null) 'rmssd': rmssd,
    if (sdnn != null) 'sdnn': sdnn,
    if (source != null) 'source': source,
    if (pnn50 != null) 'pnn50': pnn50,
    if (hr != null) 'hr': hr,
    if (score != null) 'score': score,
    if (level != null) 'level': level,
  };

  String docId() => _epochMsUtc(ts).toString();
}

// Sleep Session
class SleepSession {
  final DateTime start;
  final DateTime end;
  final int durationMinutes; // computed client side
  final Map<String, int>? stages; // deep/light/rem/awake minutes
  final String? source;

  SleepSession({
    required this.start,
    required this.end,
    required this.durationMinutes,
    this.stages,
    this.source,
  });

  factory SleepSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return SleepSession(
      start: _fromTs(data['start']),
      end: _fromTs(data['end']),
      durationMinutes: data['durationMinutes'] as int,
      stages: (data['stages'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'start': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(start)),
    'end': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(end)),
    'durationMinutes': durationMinutes,
    if (stages != null) 'stages': stages,
    if (source != null) 'source': source,
  };

  String docId() => _epochMsUtc(start).toString();
}

class PatientMetricsOverview {
  final double? avgHr;
  final double? avgSpo2;
  final double? avgHrvSdnn;
  final double? avgHrvRmssd;
  final Duration totalSleep;
  final int heartRateSamples;
  final int spo2Samples;
  final int hrvSamples;
  final int sleepSessions;

  const PatientMetricsOverview({
    this.avgHr,
    this.avgSpo2,
    this.avgHrvSdnn,
    this.avgHrvRmssd,
    required this.totalSleep,
    required this.heartRateSamples,
    required this.spo2Samples,
    required this.hrvSamples,
    required this.sleepSessions,
  });
}
