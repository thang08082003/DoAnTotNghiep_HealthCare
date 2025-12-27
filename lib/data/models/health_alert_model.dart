import 'package:cloud_firestore/cloud_firestore.dart';

/// AI prediction result from health monitoring model
class HealthPrediction {
  final double probabilityNormal;
  final double probabilityWarning;
  final double probabilityDanger;

  const HealthPrediction({
    required this.probabilityNormal,
    required this.probabilityWarning,
    required this.probabilityDanger,
  });

  AlertLevel get alertLevel {
    if (probabilityDanger > 0.3) return AlertLevel.danger;
    if (probabilityWarning > 0.3) return AlertLevel.warning;
    return AlertLevel.normal;
  }

  factory HealthPrediction.fromList(List<double> predictions) {
    if (predictions.length != 3) {
      throw ArgumentError('Predictions must have exactly 3 values');
    }
    return HealthPrediction(
      probabilityNormal: predictions[0],
      probabilityWarning: predictions[1],
      probabilityDanger: predictions[2],
    );
  }
}

enum AlertLevel {
  normal,
  warning,
  danger;

  String get displayName {
    switch (this) {
      case AlertLevel.normal:
        return 'Bình thường';
      case AlertLevel.warning:
        return 'Cảnh báo';
      case AlertLevel.danger:
        return 'Nguy hiểm';
    }
  }

  String get description {
    switch (this) {
      case AlertLevel.normal:
        return 'Các chỉ số sức khỏe đều ổn định';
      case AlertLevel.warning:
        return 'Một số chỉ số cần theo dõi';
      case AlertLevel.danger:
        return 'Chỉ số bất thường, cần khám ngay';
    }
  }
}

/// Health alert stored in Firestore
class HealthAlert {
  final String id;
  final String userId;
  final DateTime timestamp;
  final AlertLevel level;
  final HealthPrediction? prediction; // Nullable for info-only alerts
  final Map<String, double> metrics; // Input metrics that triggered alert
  final String? message;
  final bool isRead;
  final bool isDoctorNotified;

  const HealthAlert({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.level,
    this.prediction, // Made optional
    required this.metrics,
    this.message,
    required this.isRead,
    required this.isDoctorNotified,
  });

  factory HealthAlert.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return HealthAlert(
      id: doc.id,
      userId: data['userId'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      level: AlertLevel.values.firstWhere(
        (e) => e.name == data['level'],
        orElse: () => AlertLevel.normal,
      ),
      prediction: HealthPrediction(
        probabilityNormal: (data['probabilityNormal'] as num).toDouble(),
        probabilityWarning: (data['probabilityWarning'] as num).toDouble(),
        probabilityDanger: (data['probabilityDanger'] as num).toDouble(),
      ),
      metrics: (data['metrics'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      message: data['message'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      isDoctorNotified: data['isDoctorNotified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'timestamp': Timestamp.fromDate(timestamp),
    'level': level.name,
    'probabilityNormal': prediction?.probabilityNormal ?? 0.0,
    'probabilityWarning': prediction?.probabilityWarning ?? 0.0,
    'probabilityDanger': prediction?.probabilityDanger ?? 0.0,
    'metrics': metrics,
    if (message != null) 'message': message,
    'isRead': isRead,
    'isDoctorNotified': isDoctorNotified,
  };

  HealthAlert copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    AlertLevel? level,
    HealthPrediction? prediction,
    Map<String, double>? metrics,
    String? message,
    bool? isRead,
    bool? isDoctorNotified,
  }) {
    return HealthAlert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      prediction: prediction ?? this.prediction,
      metrics: metrics ?? this.metrics,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      isDoctorNotified: isDoctorNotified ?? this.isDoctorNotified,
    );
  }
}

/// Input data for AI model
class HealthMetricsInput {
  final double heartRate; // bpm
  final double spo2; // percentage
  final double sleepDuration; // hours
  final double sleepEfficiency; // percentage
  final double remPercent; // percentage
  final double deepPercent; // percentage
  final double awakeMinutes; // minutes
  bool? hasSleepData; // Flag to track if sleep data is available

  HealthMetricsInput({
    required this.heartRate,
    required this.spo2,
    required this.sleepDuration,
    required this.sleepEfficiency,
    required this.remPercent,
    required this.deepPercent,
    required this.awakeMinutes,
    this.hasSleepData,
  });

  List<double> toModelInput() {
    return [
      heartRate,
      spo2,
      sleepDuration,
      sleepEfficiency,
      remPercent,
      deepPercent,
      awakeMinutes,
    ];
  }

  Map<String, double> toMap() {
    return {
      'heart_rate': heartRate,
      'spo2': spo2,
      'sleep_duration': sleepDuration,
      'sleep_efficiency': sleepEfficiency,
      'rem_percent': remPercent,
      'deep_percent': deepPercent,
      'awake_minutes': awakeMinutes,
    };
  }

  factory HealthMetricsInput.fromMap(Map<String, double> map) {
    return HealthMetricsInput(
      heartRate: map['heart_rate'] ?? 0.0,
      spo2: map['spo2'] ?? 0.0,
      sleepDuration: map['sleep_duration'] ?? 0.0,
      sleepEfficiency: map['sleep_efficiency'] ?? 0.0,
      remPercent: map['rem_percent'] ?? 0.0,
      deepPercent: map['deep_percent'] ?? 0.0,
      awakeMinutes: map['awake_minutes'] ?? 0.0,
    );
  }

  bool get hasValidData {
    return heartRate > 0 &&
        spo2 > 0 &&
        sleepDuration > 0 &&
        sleepEfficiency >= 0 &&
        remPercent >= 0 &&
        deepPercent >= 0 &&
        awakeMinutes >= 0;
  }
}
