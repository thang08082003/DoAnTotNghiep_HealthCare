class HealthAnalysisRecord {
  final String id;
  final DateTime timestamp;
  final Map<String, dynamic>? heartRateAnalysis;
  final Map<String, dynamic>? spo2Analysis;
  final Map<String, dynamic>? sleepAnalysis;

  const HealthAnalysisRecord({
    required this.id,
    required this.timestamp,
    this.heartRateAnalysis,
    this.spo2Analysis,
    this.sleepAnalysis,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'heartRateAnalysis': heartRateAnalysis,
      'spo2Analysis': spo2Analysis,
      'sleepAnalysis': sleepAnalysis,
    };
  }

  factory HealthAnalysisRecord.fromJson(Map<String, dynamic> json) {
    return HealthAnalysisRecord(
      id: json['id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      heartRateAnalysis: json['heartRateAnalysis'] as Map<String, dynamic>?,
      spo2Analysis: json['spo2Analysis'] as Map<String, dynamic>?,
      sleepAnalysis: json['sleepAnalysis'] as Map<String, dynamic>?,
    );
  }
}
