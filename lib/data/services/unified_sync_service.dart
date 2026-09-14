import 'package:health/health.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../database/health_data_database.dart';
import '../services/health_metrics_service.dart';
import '../models/health_metric_models.dart';

/// Dịch vụ đồng bộ thống nhất: Health Connect → SQLite → Firebase
/// Sử dụng SQLite làm trung gian để validate và tránh trùng lặp
class UnifiedSyncService {
  static final UnifiedSyncService _instance = UnifiedSyncService._internal();
  factory UnifiedSyncService() => _instance;
  UnifiedSyncService._internal();

  final HealthDataDatabase _localDb = HealthDataDatabase.instance;
  final HealthMetricsService _firebaseService = HealthMetricsService();
  final Health _health = Health();

  /// Đồng bộ ngay - full sync tất cả dữ liệu
  /// [days] - số ngày lấy dữ liệu từ quá khứ (mặc định 7 ngày)
  Future<SyncResultDetail> syncImmediately({int days = 1}) async {
    debugPrint('🔄 [UnifiedSync] Bắt đầu đồng bộ ngay ($days ngày)...');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User chưa đăng nhập');
    }

    try {
      // 1. Request permissions
      final types = [
        HealthDataType.HEART_RATE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
      ];

      debugPrint('🔐 [UnifiedSync] Requesting permissions...');
      final granted = await _health.requestAuthorization(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );

      debugPrint('🔐 [UnifiedSync] Permissions granted: $granted');

      if (!granted) {
        debugPrint('❌ [UnifiedSync] Không có quyền truy cập Health Connect');
        return SyncResultDetail(
          success: false,
          message: 'Không có quyền truy cập Health Connect',
          heartRateCount: 0,
          spo2Count: 0,
          sleepCount: 0,
          uploadedToFirebase: 0,
        );
      }

      // 2. Lấy dữ liệu từ Health Connect
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      debugPrint('📥 [UnifiedSync] Đang lấy dữ liệu từ $days ngày trước...');
      debugPrint(
        '📅 [UnifiedSync] Time range: ${startDate.toString()} → ${now.toString()}',
      );

      final healthData = await _health.getHealthDataFromTypes(
        types: types,
        startTime: startDate,
        endTime: now,
      );

      debugPrint(
        '📊 [UnifiedSync] Nhận được ${healthData.length} bản ghi từ Health Connect',
      );

      // Debug: In ra từng loại dữ liệu
      final hrCount = healthData
          .where((d) => d.type == HealthDataType.HEART_RATE)
          .length;
      final spo2Count = healthData
          .where((d) => d.type == HealthDataType.BLOOD_OXYGEN)
          .length;
      final sleepCount = healthData
          .where((d) => d.type.toString().contains('SLEEP'))
          .length;
      debugPrint(
        '🔍 [UnifiedSync] HR: $hrCount, SpO2: $spo2Count, Sleep: $sleepCount',
      );

      if (healthData.isEmpty) {
        debugPrint('⚠️ [UnifiedSync] Không có dữ liệu từ Health Connect!');
        return SyncResultDetail(
          success: true,
          message: 'Không có dữ liệu mới',
          heartRateCount: 0,
          spo2Count: 0,
          sleepCount: 0,
          uploadedToFirebase: 0,
        );
      }

      // 3. Validate và lưu vào SQLite
      final validated = await _validateAndSaveToSQLite(healthData);

      debugPrint(
        '✅ [UnifiedSync] Đã lưu vào SQLite - HR: ${validated.heartRate}, SpO2: ${validated.spo2}, Sleep: ${validated.sleep}',
      );

      // 4. Đẩy từ SQLite lên Firebase
      final uploadCount = await _uploadFromSQLiteToFirebase(
        user.uid,
        startDate: startDate,
        endDate: now,
      );

      debugPrint(
        '☁️ [UnifiedSync] Đã upload ${uploadCount} bản ghi lên Firebase',
      );

      return SyncResultDetail(
        success: true,
        message: 'Đồng bộ thành công',
        heartRateCount: validated.heartRate,
        spo2Count: validated.spo2,
        sleepCount: validated.sleep,
        uploadedToFirebase: uploadCount,
      );
    } catch (e, stack) {
      debugPrint('❌ [UnifiedSync] Lỗi đồng bộ: $e');
      debugPrint('Stack: $stack');
      return SyncResultDetail(
        success: false,
        message: 'Lỗi: $e',
        heartRateCount: 0,
        spo2Count: 0,
        sleepCount: 0,
        uploadedToFirebase: 0,
      );
    }
  }

  /// Đồng bộ thụ động - chỉ lấy dữ liệu mới nhất (15 phút)
  /// Được gọi bởi WorkManager mỗi 15 phút
  Future<SyncResultDetail> syncPassive() async {
    debugPrint('⏰ [UnifiedSync] Đồng bộ thụ động (15 phút cuối)...');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ [UnifiedSync] User chưa đăng nhập, bỏ qua sync');
      return SyncResultDetail(
        success: false,
        message: 'User chưa đăng nhập',
        heartRateCount: 0,
        spo2Count: 0,
        sleepCount: 0,
        uploadedToFirebase: 0,
      );
    }

    try {
      // 1. Check permissions (không request vì đang background)
      final types = [
        HealthDataType.HEART_RATE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
      ];

      // 2. Lấy dữ liệu 30 phút gần nhất (để chắc chắn không bỏ sót)
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(minutes: 30));

      final healthData = await _health.getHealthDataFromTypes(
        types: types,
        startTime: startDate,
        endTime: now,
      );

      debugPrint(
        '📊 [UnifiedSync] Passive sync nhận ${healthData.length} bản ghi',
      );

      if (healthData.isEmpty) {
        debugPrint('ℹ️ [UnifiedSync] Không có dữ liệu mới');
        return SyncResultDetail(
          success: true,
          message: 'Không có dữ liệu mới',
          heartRateCount: 0,
          spo2Count: 0,
          sleepCount: 0,
          uploadedToFirebase: 0,
        );
      }

      // 3. Validate và lưu vào SQLite
      final validated = await _validateAndSaveToSQLite(healthData);

      // 4. Đẩy lên Firebase
      final uploadCount = await _uploadFromSQLiteToFirebase(
        user.uid,
        startDate: startDate,
        endDate: now,
      );

      debugPrint(
        '✅ [UnifiedSync] Passive sync hoàn tất - Uploaded: $uploadCount',
      );

      return SyncResultDetail(
        success: true,
        message: 'Đồng bộ thụ động thành công',
        heartRateCount: validated.heartRate,
        spo2Count: validated.spo2,
        sleepCount: validated.sleep,
        uploadedToFirebase: uploadCount,
      );
    } catch (e, stack) {
      debugPrint('❌ [UnifiedSync] Lỗi passive sync: $e');
      debugPrint('Stack: $stack');
      return SyncResultDetail(
        success: false,
        message: 'Lỗi: $e',
        heartRateCount: 0,
        spo2Count: 0,
        sleepCount: 0,
        uploadedToFirebase: 0,
      );
    }
  }

  /// Validate và lưu dữ liệu vào SQLite
  /// SQLite sử dụng UNIQUE constraints để tự động bỏ qua dữ liệu trùng
  Future<_ValidateResult> _validateAndSaveToSQLite(
    List<HealthDataPoint> healthData,
  ) async {
    int heartRateCount = 0;
    int spo2Count = 0;
    int sleepCount = 0;

    debugPrint(
      '🔍 [Validate] Bắt đầu validate ${healthData.length} data points',
    );

    // Group data by type
    final heartRateData = <Map<String, dynamic>>[];
    final spo2Data = <Map<String, dynamic>>[];
    final sleepSessions = <String, Map<String, dynamic>>{};

    for (final point in healthData) {
      try {
        switch (point.type) {
          case HealthDataType.HEART_RATE:
            final value = point.value;
            if (value is NumericHealthValue) {
              heartRateData.add({
                'timestamp': point.dateFrom.millisecondsSinceEpoch,
                'bpm': value.numericValue.toDouble(),
                'source': point.sourceName,
              });
              heartRateCount++;
            }
            break;

          case HealthDataType.BLOOD_OXYGEN:
            final value = point.value;
            if (value is NumericHealthValue) {
              spo2Data.add({
                'timestamp': point.dateFrom.millisecondsSinceEpoch,
                'percentage': value.numericValue.toDouble(),
                'source': point.sourceName,
              });
              spo2Count++;
            }
            break;

          case HealthDataType.SLEEP_SESSION:
          case HealthDataType.SLEEP_ASLEEP:
          case HealthDataType.SLEEP_AWAKE:
          case HealthDataType.SLEEP_DEEP:
          case HealthDataType.SLEEP_LIGHT:
          case HealthDataType.SLEEP_REM:
            // Aggregate sleep stages by session
            final sessionKey =
                '${point.dateFrom.millisecondsSinceEpoch}_${point.dateTo.millisecondsSinceEpoch}';

            if (!sleepSessions.containsKey(sessionKey)) {
              sleepSessions[sessionKey] = {
                'start_time': point.dateFrom.millisecondsSinceEpoch,
                'end_time': point.dateTo.millisecondsSinceEpoch,
                'light_minutes': 0,
                'deep_minutes': 0,
                'rem_minutes': 0,
                'awake_minutes': 0,
                'source': point.sourceName,
              };
            }

            final duration = point.dateTo.difference(point.dateFrom).inMinutes;

            switch (point.type) {
              case HealthDataType.SLEEP_LIGHT:
                sleepSessions[sessionKey]!['light_minutes'] = duration;
                break;
              case HealthDataType.SLEEP_DEEP:
                sleepSessions[sessionKey]!['deep_minutes'] = duration;
                break;
              case HealthDataType.SLEEP_REM:
                sleepSessions[sessionKey]!['rem_minutes'] = duration;
                break;
              case HealthDataType.SLEEP_AWAKE:
                sleepSessions[sessionKey]!['awake_minutes'] = duration;
                break;
              default:
                break;
            }
            break;

          default:
            break;
        }
      } catch (e) {
        debugPrint('⚠️ [UnifiedSync] Lỗi parse data point: $e');
        continue;
      }
    }

    // Batch insert vào SQLite với UNIQUE constraint (tự động validate trùng)
    debugPrint(
      '🔍 [Validate] Counted - HR: $heartRateCount, SpO2: $spo2Count, Sleep: ${sleepSessions.length}',
    );

    if (heartRateData.isNotEmpty) {
      await _localDb.batchInsertHeartRate(heartRateData);
      debugPrint(
        '💾 [SQLite] Inserted ${heartRateData.length} heart rate records',
      );
    } else {
      debugPrint('⚠️ [SQLite] No heart rate data to insert');
    }

    if (spo2Data.isNotEmpty) {
      await _localDb.batchInsertSpO2(spo2Data);
      debugPrint('💾 [SQLite] Inserted ${spo2Data.length} SpO2 records');
    } else {
      debugPrint('⚠️ [SQLite] No SpO2 data to insert');
    }

    if (sleepSessions.isNotEmpty) {
      sleepCount = sleepSessions.length;
      await _localDb.batchInsertSleepSessions(sleepSessions.values.toList());
      debugPrint('💾 [SQLite] Inserted ${sleepSessions.length} sleep sessions');
    } else {
      debugPrint('⚠️ [SQLite] No sleep data to insert');
    }

    return _ValidateResult(
      heartRate: heartRateCount,
      spo2: spo2Count,
      sleep: sleepCount,
    );
  }

  /// Đẩy dữ liệu từ SQLite lên Firebase
  Future<int> _uploadFromSQLiteToFirebase(
    String uid, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    int totalUploaded = 0;

    try {
      final startTimestamp = startDate.millisecondsSinceEpoch;
      final endTimestamp = endDate.millisecondsSinceEpoch;

      // 1. Query heart rate từ SQLite
      final heartRateRows = await _localDb.queryHeartRate(
        startTime: startTimestamp,
        endTime: endTimestamp,
      );

      if (heartRateRows.isNotEmpty) {
        final samples = heartRateRows.map((row) {
          return HeartRateSample(
            ts: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
            bpm: (row['bpm'] as num).toDouble(),
            source: row['source'] as String? ?? 'sqlite',
          );
        }).toList();

        await _firebaseService.saveHeartRates(uid, samples);
        totalUploaded += samples.length;
        debugPrint(
          '☁️ [Firebase] Uploaded ${samples.length} heart rate samples',
        );
      }

      // 2. Query SpO2 từ SQLite
      final spo2Rows = await _localDb.querySpO2(
        startTime: startTimestamp,
        endTime: endTimestamp,
      );

      if (spo2Rows.isNotEmpty) {
        final samples = spo2Rows.map((row) {
          return Spo2Sample(
            ts: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
            percentage: (row['percentage'] as num).toDouble(),
            source: row['source'] as String? ?? 'sqlite',
          );
        }).toList();

        await _firebaseService.saveSpo2(uid, samples);
        totalUploaded += samples.length;
        debugPrint('☁️ [Firebase] Uploaded ${samples.length} SpO2 samples');
      }

      // 3. Query sleep sessions từ SQLite
      final sleepRows = await _localDb.querySleepSessions(
        startTime: startTimestamp,
        endTime: endTimestamp,
      );

      if (sleepRows.isNotEmpty) {
        final sessions = sleepRows.map((row) {
          final start = DateTime.fromMillisecondsSinceEpoch(
            row['start_time'] as int,
          );
          final end = DateTime.fromMillisecondsSinceEpoch(
            row['end_time'] as int,
          );
          final duration = end.difference(start).inMinutes;

          return SleepSession(
            start: start,
            end: end,
            durationMinutes: duration,
            source: row['source'] as String? ?? 'sqlite',
            stages: [
              if (row['light_minutes'] != null && row['light_minutes'] > 0)
                SleepStageDetail(
                  start: start,
                  end: start.add(
                    Duration(minutes: row['light_minutes'] as int),
                  ),
                  durationMinutes: row['light_minutes'] as int,
                  stage: 'light',
                ),
              if (row['deep_minutes'] != null && row['deep_minutes'] > 0)
                SleepStageDetail(
                  start: start,
                  end: start.add(Duration(minutes: row['deep_minutes'] as int)),
                  durationMinutes: row['deep_minutes'] as int,
                  stage: 'deep',
                ),
              if (row['rem_minutes'] != null && row['rem_minutes'] > 0)
                SleepStageDetail(
                  start: start,
                  end: start.add(Duration(minutes: row['rem_minutes'] as int)),
                  durationMinutes: row['rem_minutes'] as int,
                  stage: 'rem',
                ),
              if (row['awake_minutes'] != null && row['awake_minutes'] > 0)
                SleepStageDetail(
                  start: start,
                  end: start.add(
                    Duration(minutes: row['awake_minutes'] as int),
                  ),
                  durationMinutes: row['awake_minutes'] as int,
                  stage: 'awake',
                ),
            ],
          );
        }).toList();

        await _firebaseService.saveSleepSessions(uid, sessions);
        totalUploaded += sessions.length;
        debugPrint('☁️ [Firebase] Uploaded ${sessions.length} sleep sessions');
      }

      return totalUploaded;
    } catch (e, stack) {
      debugPrint('❌ [Firebase] Lỗi upload: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }
}

/// Kết quả validate nội bộ
class _ValidateResult {
  final int heartRate;
  final int spo2;
  final int sleep;

  _ValidateResult({
    required this.heartRate,
    required this.spo2,
    required this.sleep,
  });
}

/// Kết quả đồng bộ chi tiết
class SyncResultDetail {
  final bool success;
  final String message;
  final int heartRateCount;
  final int spo2Count;
  final int sleepCount;
  final int uploadedToFirebase;

  SyncResultDetail({
    required this.success,
    required this.message,
    required this.heartRateCount,
    required this.spo2Count,
    required this.sleepCount,
    required this.uploadedToFirebase,
  });

  @override
  String toString() {
    return 'SyncResult(success: $success, message: $message, '
        'HR: $heartRateCount, SpO2: $spo2Count, Sleep: $sleepCount, '
        'Uploaded: $uploadedToFirebase)';
  }
}
