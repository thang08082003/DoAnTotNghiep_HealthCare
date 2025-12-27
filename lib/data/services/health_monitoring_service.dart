import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:health/health.dart';
import '../models/health_alert_model.dart';
import '../repositories/health_alert_repository.dart';
import '../services/health_connect_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HealthMonitoringService {
  final HealthAlertRepository _alertRepository;
  final GoogleFitService _healthService;
  final FlutterLocalNotificationsPlugin _notifications;

  HealthMonitoringService({
    required HealthAlertRepository alertRepository,
    required GoogleFitService healthService,
    required FlutterLocalNotificationsPlugin notifications,
  }) : _alertRepository = alertRepository,
       _healthService = healthService,
       _notifications = notifications;

  /// Collect latest health metrics from Health Connect
  Future<HealthMetricsInput?> collectHealthMetrics(String userId) async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      // Get latest heart rate
      final hrData = await _healthService.getDataFast(
        types: const [HealthDataType.HEART_RATE],
        start: yesterday,
        end: now,
      );

      double? heartRate;
      if (hrData.isNotEmpty) {
        final latest = hrData.last;
        if (latest.value is NumericHealthValue) {
          heartRate = (latest.value as NumericHealthValue).numericValue
              .toDouble();
        }
      }

      // Get latest SpO2
      final spo2Data = await _healthService.getDataFast(
        types: const [HealthDataType.BLOOD_OXYGEN],
        start: yesterday,
        end: now,
      );

      double? spo2;
      if (spo2Data.isNotEmpty) {
        final latest = spo2Data.last;
        if (latest.value is NumericHealthValue) {
          spo2 = (latest.value as NumericHealthValue).numericValue.toDouble();
        }
      }

      // Get last night's sleep
      final sleepStart = DateTime(
        now.year,
        now.month,
        now.day - 1,
        20,
        0,
      ); // 8 PM yesterday
      final sleepEnd = DateTime(
        now.year,
        now.month,
        now.day,
        12,
        0,
      ); // 12 PM today

      final sleepData = await _healthService.getDataFast(
        types: const [HealthDataType.SLEEP_SESSION],
        start: sleepStart,
        end: sleepEnd,
      );

      double sleepDuration = 0;
      double sleepEfficiency = 0;
      double remPercent = 0;
      double deepPercent = 0;
      double awakeMinutes = 0;

      if (sleepData.isNotEmpty) {
        final session = sleepData.last;
        final duration = session.dateTo.difference(session.dateFrom);
        sleepDuration = duration.inMinutes / 60.0; // hours

        // Get sleep stages
        final stageData = await _healthService.getDataFast(
          types: const [
            HealthDataType.SLEEP_LIGHT,
            HealthDataType.SLEEP_DEEP,
            HealthDataType.SLEEP_REM,
            HealthDataType.SLEEP_AWAKE,
          ],
          start: session.dateFrom,
          end: session.dateTo,
        );

        int deepMinutes = 0;
        int remMinutes = 0;
        int lightMinutes = 0;
        int awake = 0;

        for (final stage in stageData) {
          final stageDuration = stage.dateTo
              .difference(stage.dateFrom)
              .inMinutes;
          switch (stage.type) {
            case HealthDataType.SLEEP_DEEP:
              deepMinutes += stageDuration;
              break;
            case HealthDataType.SLEEP_REM:
              remMinutes += stageDuration;
              break;
            case HealthDataType.SLEEP_LIGHT:
              lightMinutes += stageDuration;
              break;
            case HealthDataType.SLEEP_AWAKE:
              awake += stageDuration;
              break;
            default:
              break;
          }
        }

        final totalSleep = deepMinutes + remMinutes + lightMinutes;
        if (totalSleep > 0) {
          sleepEfficiency = (totalSleep / duration.inMinutes) * 100.0;
          remPercent = (remMinutes / totalSleep) * 100.0;
          deepPercent = (deepMinutes / totalSleep) * 100.0;
        }
        awakeMinutes = awake.toDouble();
      }

      // Check if we have enough data (at least HR and SpO2)
      if (heartRate == null || spo2 == null) {
        return null;
      }

      // If no sleep data, use null/zero to indicate missing data
      // AI model should handle missing features appropriately
      final hasSleepData = sleepDuration > 0;
      if (!hasSleepData) {
        // Keep sleepDuration = 0 to indicate no data
        // Keep other sleep metrics at 0.0 (default from initialization)
      }

      final metrics = HealthMetricsInput(
        heartRate: heartRate,
        spo2: spo2,
        sleepDuration: sleepDuration,
        sleepEfficiency: sleepEfficiency,
        remPercent: remPercent,
        deepPercent: deepPercent,
        awakeMinutes: awakeMinutes,
      );

      // Store flag for later use
      metrics.hasSleepData = hasSleepData;

      return metrics;
    } catch (e) {
      return null;
    }
  }

  /// Run AI model prediction (placeholder - integrate your actual model here)
  Future<HealthPrediction> runPrediction(HealthMetricsInput input) async {
    // TODO: Replace with actual TensorFlow Lite model inference
    // For now, use rule-based logic as placeholder

    // Placeholder logic
    double dangerScore = 0.0;
    double warningScore = 0.0;

    // Check heart rate
    if (input.heartRate < 40 || input.heartRate > 120) {
      dangerScore += 0.4;
    } else if (input.heartRate < 50 || input.heartRate > 100) {
      warningScore += 0.3;
    }

    // Check SpO2
    if (input.spo2 < 90) {
      dangerScore += 0.5;
    } else if (input.spo2 < 95) {
      warningScore += 0.3;
    }

    // Check sleep (only if data available)
    if (input.sleepDuration > 0) {
      if (input.sleepDuration < 5) {
        dangerScore += 0.3;
      } else if (input.sleepDuration < 6) {
        warningScore += 0.2;
      }

      if (input.sleepEfficiency < 70) {
        warningScore += 0.2;
      }
    }

    // Normalize scores
    dangerScore = dangerScore.clamp(0.0, 1.0);
    warningScore = (warningScore + (dangerScore * 0.5)).clamp(0.0, 1.0);
    double normalScore = (1.0 - dangerScore - warningScore).clamp(0.0, 1.0);

    // Ensure sum is 1.0
    final total = normalScore + warningScore + dangerScore;
    if (total > 0) {
      normalScore /= total;
      warningScore /= total;
      dangerScore /= total;
    }

    final prediction = HealthPrediction(
      probabilityNormal: normalScore,
      probabilityWarning: warningScore,
      probabilityDanger: dangerScore,
    );

    return prediction;
  }

  /// Process monitoring for a user
  Future<Map<String, dynamic>> monitorUser(String userId) async {
    try {
      // Collect metrics
      final metrics = await collectHealthMetrics(userId);
      if (metrics == null || !metrics.hasValidData) {
        return {'hasSleepData': false};
      }

      // Check if we have sleep data
      final hasSleepData = metrics.hasSleepData ?? metrics.sleepDuration > 0;

      HealthAlert alert;

      if (!hasSleepData) {
        // Create info-only alert without prediction
        alert = HealthAlert(
          id: '',
          userId: userId,
          timestamp: DateTime.now(),
          level: AlertLevel.normal, // Use normal level for info
          prediction: null, // No prediction without sleep data
          metrics: metrics.toMap(),
          message: _generateInfoMessage(metrics),
          isRead: false,
          isDoctorNotified: false,
        );
      } else {
        // Run prediction with full data
        final prediction = await runPrediction(metrics);

        alert = HealthAlert(
          id: '',
          userId: userId,
          timestamp: DateTime.now(),
          level: prediction.alertLevel,
          prediction: prediction,
          metrics: metrics.toMap(),
          message: _generateAlertMessage(prediction, metrics),
          isRead: false,
          isDoctorNotified: false,
        );
      }

      // Save to Firestore
      final alertId = await _alertRepository.saveAlert(alert);

      // Send notification to patient (for all levels)
      await _sendPatientNotification(alert);

      // Notify doctor if danger level and has prediction
      if (alert.prediction != null &&
          alert.prediction!.alertLevel == AlertLevel.danger) {
        await _notifyDoctor(userId, alert);
        await _alertRepository.markDoctorNotified(alertId);
      }

      return {'hasSleepData': hasSleepData};
    } catch (e) {
      rethrow;
    }
  }

  /// Generate info message when sleep data is missing
  String _generateInfoMessage(HealthMetricsInput metrics) {
    final info = <String>[];

    // Show current metrics
    info.add('Nhịp tim: ${metrics.heartRate.toStringAsFixed(0)} bpm');
    info.add('SpO2: ${metrics.spo2.toStringAsFixed(1)}%');

    // Add status indicators
    if (metrics.heartRate < 50 || metrics.heartRate > 100) {
      info.add('⚠️ Nhịp tim cần theo dõi');
    }
    if (metrics.spo2 < 95) {
      info.add('⚠️ SpO2 thấp');
    }

    final message = info.join(' • ');
    return '$message\n\n💤 Chưa có dữ liệu giấc ngủ. Vui lòng kết nối thiết bị theo dõi giấc ngủ để có đánh giá đầy đủ hơn.';
  }

  String _generateAlertMessage(
    HealthPrediction prediction,
    HealthMetricsInput metrics,
  ) {
    final issues = <String>[];

    // Check for specific issues
    if (metrics.heartRate < 50) {
      issues.add('Nhịp tim thấp (${metrics.heartRate.toStringAsFixed(0)} bpm)');
    } else if (metrics.heartRate > 100) {
      issues.add('Nhịp tim cao (${metrics.heartRate.toStringAsFixed(0)} bpm)');
    }

    if (metrics.spo2 < 95) {
      issues.add('SpO2 thấp (${metrics.spo2.toStringAsFixed(1)}%)');
    }

    if (metrics.sleepDuration < 6) {
      issues.add('Thiếu ngủ (${metrics.sleepDuration.toStringAsFixed(1)}h)');
    }

    // Generate message based on alert level
    if (prediction.alertLevel == AlertLevel.normal) {
      if (issues.isEmpty) {
        return 'Tất cả các chỉ số sức khỏe đều ổn định';
      } else {
        return 'Các chỉ số sức khỏe bình thường: ${issues.join(', ')}';
      }
    }

    if (issues.isEmpty) {
      return 'Một số chỉ số sức khỏe cần theo dõi';
    }

    return issues.join(', ');
  }

  Future<void> _sendPatientNotification(HealthAlert alert) async {
    const androidDetails = AndroidNotificationDetails(
      'health_monitoring',
      'Giám sát sức khỏe',
      channelDescription: 'Thông báo cảnh báo sức khỏe từ hệ thống',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_notify',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      alert.timestamp.millisecondsSinceEpoch ~/ 1000,
      alert.level == AlertLevel.danger
          ? '⚠️ Cảnh báo sức khỏe khẩn cấp'
          : alert.level == AlertLevel.warning
          ? '⚠️ Cảnh báo sức khỏe'
          : '✅ Kết quả phân tích sức khỏe',
      alert.message ?? alert.level.description,
      details,
      payload: 'health_alert:${alert.id}',
    );
  }

  Future<void> _notifyDoctor(String patientId, HealthAlert alert) async {
    try {
      // Get patient's assigned doctors
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('patient_doctor_assignments')
          .where('patientId', isEqualTo: patientId)
          .get();

      if (assignmentsSnapshot.docs.isEmpty) {
        return;
      }

      // Get patient name
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();
      final patientName = patientDoc.data()?['name'] as String? ?? 'Bệnh nhân';

      // Create notification for each doctor
      final batch = FirebaseFirestore.instance.batch();
      for (final assignment in assignmentsSnapshot.docs) {
        final doctorId = assignment.data()['doctorId'] as String;

        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'userId': doctorId,
          'title': '🚨 Cảnh báo sức khỏe bệnh nhân',
          'body': '$patientName: ${alert.message}',
          'type': 'health_alert',
          'data': {
            'patientId': patientId,
            'alertId': alert.id,
            'level': alert.level.name,
          },
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      await batch.commit();
    } catch (e) {
      // Silently catch notification errors
    }
  }
}
