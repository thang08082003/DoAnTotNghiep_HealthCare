import 'package:cloud_firestore/cloud_firestore.dart';

// Base helpers
DateTime _fromTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
  }
  throw ArgumentError('Unsupported timestamp value: $v');
}

int _epochMsUtc(DateTime dt) => dt.toUtc().millisecondsSinceEpoch;

// Heart Rate
class HeartRateSample {
  final DateTime ts; // timestamp of sample
  final double bpm;
  final String? source;

  HeartRateSample({required this.ts, required this.bpm, this.source});

  factory HeartRateSample.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return HeartRateSample(
      ts: _fromTs(data['ts']),
      bpm: (data['bpm'] as num).toDouble(),
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'ts': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(ts)),
    'bpm': bpm,
    if (source != null) 'source': source,
  };

  String docId() => _epochMsUtc(ts).toString();
}

// SpO2
class Spo2Sample {
  final DateTime ts;
  final double percentage; // 0-100
  final String? source;

  Spo2Sample({required this.ts, required this.percentage, this.source});

  factory Spo2Sample.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Use unified field name 'percentage'
    final pctVal = data['percentage'];
    return Spo2Sample(
      ts: _fromTs(data['ts']),
      percentage: (pctVal as num).toDouble(),
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'ts': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(ts)),
    'percentage': percentage,
    if (source != null) 'source': source,
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

// Sleep Session with embedded stages
class SleepSession {
  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final List<SleepStageDetail>? stages; // Detailed stage list
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
    List<SleepStageDetail>? stagesList;
    if (data['stages'] != null) {
      final stagesData = data['stages'];
      if (stagesData is List) {
        // New format: array of stage objects
        stagesList = (stagesData)
            .map((s) => SleepStageDetail.fromMap(s as Map<String, dynamic>))
            .toList();
      }
    }

    return SleepSession(
      start: _fromTs(data['start']),
      end: _fromTs(data['end']),
      durationMinutes: data['durationMinutes'] as int,
      stages: stagesList,
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'start': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(start)),
    'end': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(end)),
    'durationMinutes': durationMinutes,
    if (stages != null) 'stages': stages!.map((s) => s.toMap()).toList(),
    if (source != null) 'source': source,
  };

  String docId() => _epochMsUtc(start).toString();
}

// Sleep stage detail (embedded in session)
class SleepStageDetail {
  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final String stage;

  SleepStageDetail({
    required this.start,
    required this.end,
    required this.durationMinutes,
    required this.stage,
  });

  factory SleepStageDetail.fromMap(Map<String, dynamic> data) {
    return SleepStageDetail(
      start: _fromTs(data['start']),
      end: _fromTs(data['end']),
      durationMinutes: (data['durationMinutes'] as num).toInt(),
      stage: data['stage'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'start': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(start)),
    'end': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(end)),
    'durationMinutes': durationMinutes,
    'stage': stage,
  };
}

// Sleep Stage (individual stage within a session)
class SleepStage {
  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final String
  stage; // "light", "deep", "rem", "awake", "sleeping", "out_of_bed", "unknown"
  final String? sessionMetaId;
  final String? source;

  SleepStage({
    required this.start,
    required this.end,
    required this.durationMinutes,
    required this.stage,
    this.sessionMetaId,
    this.source,
  });

  factory SleepStage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SleepStage(
      start: _fromTs(data['start']),
      end: _fromTs(data['end']),
      durationMinutes: data['durationMinutes'] as int,
      stage: data['stage'] as String,
      sessionMetaId: data['sessionMetaId'] as String?,
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'start': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(start)),
    'end': Timestamp.fromMillisecondsSinceEpoch(_epochMsUtc(end)),
    'durationMinutes': durationMinutes,
    'stage': stage,
    if (sessionMetaId != null) 'sessionMetaId': sessionMetaId,
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
