import 'package:health/health.dart';
import '../database/health_data_database.dart';
import '../services/health_connect_service.dart';
import '../services/sleep_analysis_service.dart';

class HealthAnalysisRepository {
  final HealthDataDatabase _database = HealthDataDatabase.instance;
  final GoogleFitService _healthService = GoogleFitService();
  final SleepAnalysisService _sleepAnalysisService = SleepAnalysisService();

  // Sync all health data from Health Connect and store in local database
  Future<void> syncHealthData() async {
    // 1. Ensure Health Connect is connected
    final connected = await _healthService.ensureConnected();
    if (!connected) {
      throw Exception('Không thể kết nối với Health Connect');
    }

    // 2. Fetch data from beginning of time to now
    final now = DateTime.now();
    final startDate = DateTime(2020, 1, 1); // Far back in the past

    // Sync Heart Rate
    await _syncHeartRate(startDate, now);

    // Sync SpO2
    await _syncSpO2(startDate, now);

    // Sync Sleep Sessions
    await _syncSleepSessions(startDate, now);
  }

  // Private method to sync heart rate data
  Future<void> _syncHeartRate(DateTime start, DateTime end) async {
    try {
      final data = await _healthService.getData(
        types: [HealthDataType.HEART_RATE],
        start: start,
        end: end,
      );

      if (data.isEmpty) return;

      final heartRateData = data
          .where((point) => point.type == HealthDataType.HEART_RATE)
          .map((point) {
            final value = point.value;
            double bpm;
            if (value is NumericHealthValue) {
              bpm = value.numericValue.toDouble();
            } else {
              bpm = (value as num).toDouble();
            }
            return {
              'timestamp': point.dateFrom.millisecondsSinceEpoch,
              'bpm': bpm,
              'source': point.sourceName,
            };
          })
          .toList();

      if (heartRateData.isNotEmpty) {
        await _database.batchInsertHeartRate(heartRateData);
      }
    } catch (e) {
      throw Exception('Lỗi khi đồng bộ dữ liệu nhịp tim: $e');
    }
  }

  // Private method to sync SpO2 data
  Future<void> _syncSpO2(DateTime start, DateTime end) async {
    try {
      final data = await _healthService.getData(
        types: [HealthDataType.BLOOD_OXYGEN],
        start: start,
        end: end,
      );

      if (data.isEmpty) return;

      final spo2Data = data
          .where((point) => point.type == HealthDataType.BLOOD_OXYGEN)
          .map((point) {
            final value = point.value;
            double percentage;
            if (value is NumericHealthValue) {
              percentage = value.numericValue.toDouble();
            } else {
              percentage = (value as num).toDouble();
            }
            return {
              'timestamp': point.dateFrom.millisecondsSinceEpoch,
              'percentage': percentage,
              'source': point.sourceName,
            };
          })
          .toList();

      if (spo2Data.isNotEmpty) {
        await _database.batchInsertSpO2(spo2Data);
      }
    } catch (e) {
      throw Exception('Lỗi khi đồng bộ dữ liệu SpO2: $e');
    }
  }

  // Private method to sync sleep sessions
  Future<void> _syncSleepSessions(DateTime start, DateTime end) async {
    try {
      final sleepTypes = [
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_AWAKE,
      ];

      final data = await _healthService.getData(
        types: sleepTypes,
        start: start,
        end: end,
      );

      if (data.isEmpty) return;

      // Group by session (by dateFrom)
      final Map<int, Map<String, dynamic>> sessions = {};

      for (final point in data) {
        final sessionStart = point.dateFrom.millisecondsSinceEpoch;
        final sessionEnd = point.dateTo.millisecondsSinceEpoch;
        final durationMinutes = (sessionEnd - sessionStart) ~/ (1000 * 60);

        if (!sessions.containsKey(sessionStart)) {
          sessions[sessionStart] = {
            'start_time': sessionStart,
            'end_time': sessionEnd,
            'light_minutes': 0,
            'deep_minutes': 0,
            'rem_minutes': 0,
            'awake_minutes': 0,
            'source': point.sourceName,
          };
        }

        // Update session based on sleep stage
        switch (point.type) {
          case HealthDataType.SLEEP_LIGHT:
            sessions[sessionStart]!['light_minutes'] =
                (sessions[sessionStart]!['light_minutes'] as int) +
                durationMinutes;
            break;
          case HealthDataType.SLEEP_DEEP:
            sessions[sessionStart]!['deep_minutes'] =
                (sessions[sessionStart]!['deep_minutes'] as int) +
                durationMinutes;
            break;
          case HealthDataType.SLEEP_REM:
            sessions[sessionStart]!['rem_minutes'] =
                (sessions[sessionStart]!['rem_minutes'] as int) +
                durationMinutes;
            break;
          case HealthDataType.SLEEP_AWAKE:
            sessions[sessionStart]!['awake_minutes'] =
                (sessions[sessionStart]!['awake_minutes'] as int) +
                durationMinutes;
            break;
          case HealthDataType.SLEEP_SESSION:
            // Update end time if this is the main session
            sessions[sessionStart]!['end_time'] = sessionEnd;
            break;
          default:
            break;
        }
      }

      if (sessions.isNotEmpty) {
        await _database.batchInsertSleepSessions(sessions.values.toList());
      }
    } catch (e) {
      throw Exception('Lỗi khi đồng bộ dữ liệu giấc ngủ: $e');
    }
  }

  // Query and analyze heart rate data
  Future<Map<String, dynamic>> analyzeHeartRate() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Get today's data
    final data = await _database.queryHeartRate(
      startTime: startOfToday.millisecondsSinceEpoch,
      endTime: now.millisecondsSinceEpoch,
    );

    if (data.isEmpty) {
      return {
        'count': 0,
        'average': 0.0,
        'min': 0.0,
        'max': 0.0,
        'latest': null,
        'baseline': 75.0,
        'context': 'unknown',
        'anomaly': null,
      };
    }

    // Filter: Only use waking hours data (6:00 - 23:00)
    final wakingHoursData = data.where((e) {
      final timestamp = e['timestamp'] as int;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final hour = dateTime.hour;
      return hour >= 6 && hour < 23;
    }).toList();

    if (wakingHoursData.isEmpty) {
      return {
        'count': 0,
        'average': 0.0,
        'min': 0.0,
        'max': 0.0,
        'latest': null,
        'baseline': 75.0,
        'context': 'unknown',
        'anomaly': null,
      };
    }

    // Calculate today's average from waking hours only
    final bpmValues = wakingHoursData.map((e) => e['bpm'] as double).toList();
    final average = bpmValues.reduce((a, b) => a + b) / bpmValues.length;
    final min = bpmValues.reduce((a, b) => a < b ? a : b);
    final max = bpmValues.reduce((a, b) => a > b ? a : b);

    // Detect context based ONLY on BPM value (ignore time for average)
    final currentContext = _detectHeartRateContextByValue(average);

    // Calculate context-specific baseline
    final baseline = await _calculateHeartRateBaseline(
      currentContext,
      startOfToday,
    );

    // Context-aware anomaly detection
    final anomaly = _detectHeartRateAnomaly(average, baseline, currentContext);

    print(
      'DEBUG Heart Rate: average=$average, baseline=$baseline, context=$currentContext, anomaly=$anomaly',
    );

    return {
      'count': wakingHoursData.length,
      'average': average,
      'min': min,
      'max': max,
      'latest': wakingHoursData.last,
      'baseline': baseline,
      'context': currentContext,
      'anomaly': anomaly,
    };
  }

  // Query and analyze SpO2 data
  Future<Map<String, dynamic>> analyzeSpO2() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Get today's data
    final data = await _database.querySpO2(
      startTime: startOfToday.millisecondsSinceEpoch,
      endTime: now.millisecondsSinceEpoch,
    );

    if (data.isEmpty) {
      return {
        'count': 0,
        'average': 0.0,
        'min': 0.0,
        'max': 0.0,
        'latest': null,
        'baseline': 97.0,
        'context': 'unknown',
        'anomaly': null,
      };
    }

    // Filter: Only use waking hours data (6:00 - 23:00)
    final wakingHoursData = data.where((e) {
      final timestamp = e['timestamp'] as int;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final hour = dateTime.hour;
      return hour >= 6 && hour < 23;
    }).toList();

    if (wakingHoursData.isEmpty) {
      return {
        'count': 0,
        'average': 0.0,
        'min': 0.0,
        'max': 0.0,
        'latest': null,
        'baseline': 97.0,
        'context': 'awake',
        'anomaly': null,
      };
    }

    // Calculate average from waking hours only
    final percentages = wakingHoursData
        .map((e) => e['percentage'] as double)
        .toList();
    final average = percentages.reduce((a, b) => a + b) / percentages.length;
    final min = percentages.reduce((a, b) => a < b ? a : b);
    final max = percentages.reduce((a, b) => a > b ? a : b);

    // Use awake context by default (SpO2 doesn't vary much by context)
    const currentContext = 'awake';

    // Calculate context-specific baseline
    final baseline = await _calculateSpO2Baseline(currentContext, startOfToday);

    // Context-aware anomaly detection
    final anomaly = _detectSpO2Anomaly(average, baseline, currentContext);

    return {
      'count': wakingHoursData.length,
      'average': average,
      'min': min,
      'max': max,
      'latest': wakingHoursData.last,
      'baseline': baseline,
      'context': currentContext,
      'anomaly': anomaly,
    };
  }

  // Query and analyze sleep data with advanced analysis
  Future<Map<String, dynamic>> analyzeSleep() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Get today's sleep data
    final data = await _database.querySleepSessions(
      startTime: startOfToday.millisecondsSinceEpoch,
      endTime: now.millisecondsSinceEpoch,
    );

    if (data.isEmpty) {
      return {
        'count': 0,
        'totalMinutes': 0,
        'averageMinutes': 0.0,
        'lightMinutes': 0,
        'deepMinutes': 0,
        'remMinutes': 0,
        'awakeMinutes': 0,
        'status': 'unknown',
        'issues': ['Không có dữ liệu giấc ngủ'],
        'recommendations': [],
      };
    }

    // Calculate totals for today
    int totalLight = 0;
    int totalDeep = 0;
    int totalRem = 0;
    int totalAwake = 0;
    int totalMinutes = 0;

    for (final session in data) {
      totalLight += (session['light_minutes'] as int?) ?? 0;
      totalDeep += (session['deep_minutes'] as int?) ?? 0;
      totalRem += (session['rem_minutes'] as int?) ?? 0;
      totalAwake += (session['awake_minutes'] as int?) ?? 0;

      final duration =
          ((session['end_time'] as int) - (session['start_time'] as int)) ~/
          (1000 * 60);
      totalMinutes += duration;
    }

    // Get 7-day baseline for personalized comparison
    final baseline = await _calculate7DayBaseline(startOfToday);

    // Perform advanced analysis
    final analysis = _sleepAnalysisService.analyzeSleepQuality(
      lightMinutes: totalLight,
      deepMinutes: totalDeep,
      remMinutes: totalRem,
      awakeMinutes: totalAwake,
      baseline: baseline,
    );

    // Merge with basic data
    return {
      'count': data.length,
      'totalMinutes': totalMinutes,
      'averageMinutes': data.isNotEmpty ? totalMinutes / data.length : 0.0,
      'lightMinutes': totalLight,
      'deepMinutes': totalDeep,
      'remMinutes': totalRem,
      'awakeMinutes': totalAwake,
      ...analysis, // Include status, issues, recommendations, percentages
    };
  }

  /// Calculate 7-day baseline for sleep stages
  /// Returns average percentages for light, deep, and REM sleep
  Future<Map<String, double>> _calculate7DayBaseline(DateTime today) async {
    final List<Map<String, int>> last7Days = [];

    // Query each of the past 7 days
    for (int i = 1; i <= 7; i++) {
      final dayStart = today.subtract(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayData = await _database.querySleepSessions(
        startTime: dayStart.millisecondsSinceEpoch,
        endTime: dayEnd.millisecondsSinceEpoch,
      );

      if (dayData.isNotEmpty) {
        int light = 0;
        int deep = 0;
        int rem = 0;

        for (final session in dayData) {
          light += (session['light_minutes'] as int?) ?? 0;
          deep += (session['deep_minutes'] as int?) ?? 0;
          rem += (session['rem_minutes'] as int?) ?? 0;
        }

        last7Days.add({'light': light, 'deep': deep, 'rem': rem});
      }
    }

    return _sleepAnalysisService.calculateBaseline(last7Days);
  }

  // ============================================================================
  // CONTEXT-AWARE ANALYSIS HELPERS
  // ============================================================================

  /// Detect heart rate context based on value and time
  /// Returns: 'sleeping', 'resting', 'light_active', or 'active'
  String _detectHeartRateContext(double bpm, DateTime time) {
    final hour = time.hour;

    // Sleep hours (23:00 - 6:00) -> sleeping (don't use for baseline)
    if (hour >= 23 || hour < 6) {
      return 'sleeping';
    }

    // Waking hours - classify by BPM
    if (bpm < 70) {
      return 'resting'; // Sitting/relaxing during waking hours
    } else if (bpm < 100) {
      return 'light_active'; // Normal daily activities
    } else {
      return 'active'; // Exercise/stress
    }
  }

  /// Detect heart rate context based ONLY on BPM value (for average analysis)
  /// Returns: 'resting', 'light_active', or 'active'
  String _detectHeartRateContextByValue(double bpm) {
    if (bpm < 70) {
      return 'resting'; // Sitting/relaxing
    } else if (bpm < 100) {
      return 'light_active'; // Normal daily activities
    } else {
      return 'active'; // Exercise/stress
    }
  }

  /// Calculate trimmed mean (remove outliers from both ends)
  double _calculateTrimmedMean(
    List<double> values, {
    double trimPercent = 0.1,
  }) {
    if (values.isEmpty) return 0.0;
    if (values.length < 10) {
      // Too few values, just use regular mean
      return values.reduce((a, b) => a + b) / values.length;
    }

    final sorted = List<double>.from(values)..sort();
    final removeCount = (sorted.length * trimPercent).ceil();

    if (sorted.length <= removeCount * 2) {
      // Can't trim, use all data
      return values.reduce((a, b) => a + b) / values.length;
    }

    final trimmed = sorted.sublist(removeCount, sorted.length - removeCount);
    return trimmed.reduce((a, b) => a + b) / trimmed.length;
  }

  /// Calculate baseline for specific context
  Future<double> _calculateHeartRateBaseline(
    String context,
    DateTime startOfToday,
  ) async {
    final sevenDaysAgo = startOfToday.subtract(const Duration(days: 7));
    final yesterday = startOfToday.subtract(const Duration(days: 1));

    final baselineData = await _database.queryHeartRate(
      startTime: sevenDaysAgo.millisecondsSinceEpoch,
      endTime: yesterday.millisecondsSinceEpoch,
    );

    if (baselineData.isEmpty) {
      // Return default baseline by context
      switch (context) {
        case 'sleeping':
          return 60.0; // Not used for comparison
        case 'resting':
          return 65.0;
        case 'light_active':
          return 75.0;
        case 'active':
          return 100.0;
        default:
          return 75.0;
      }
    }

    // Filter data by context (exclude sleeping hours entirely)
    final contextData = baselineData.where((e) {
      final timestamp = e['timestamp'] as int;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final hour = dateTime.hour;

      // Skip sleeping hours completely
      if (hour >= 23 || hour < 6) {
        return false;
      }

      final bpm = e['bpm'] as double;
      final dataContext = _detectHeartRateContext(bpm, dateTime);
      return dataContext == context;
    }).toList();

    print(
      'DEBUG Baseline calc: context=$context, total data=${baselineData.length}, filtered=${contextData.length}',
    );

    if (contextData.isNotEmpty) {
      // Show sample of the filtered data
      final sample = contextData.take(5).map((e) => e['bpm']).toList();
      print('DEBUG Sample BPM values: $sample');
    }

    if (contextData.isEmpty) {
      // No data for this context, fallback to default
      switch (context) {
        case 'sleeping':
          return 60.0;
        case 'resting':
          return 65.0;
        case 'light_active':
          return 75.0;
        case 'active':
          return 100.0;
        default:
          return 75.0;
      }
    }

    // Calculate trimmed mean baseline
    final bpmValues = contextData.map((e) => e['bpm'] as double).toList();
    final baseline = _calculateTrimmedMean(bpmValues);
    print('DEBUG Baseline result: $baseline from ${bpmValues.length} values');
    return baseline;
  }

  /// Detect anomaly with context-aware thresholds
  String? _detectHeartRateAnomaly(
    double average,
    double baseline,
    String context,
  ) {
    // Calculate deviation percentage
    final deviation = (average - baseline) / baseline * 100;

    // Context-specific thresholds
    double alertThreshold;
    String contextLabel;

    switch (context) {
      case 'sleeping':
        alertThreshold = 25.0; // Sleeping hours
        contextLabel = 'lúc ngủ';
        break;
      case 'resting':
        alertThreshold = 20.0; // More sensitive when resting
        contextLabel = 'lúc nghỉ ngơi';
        break;
      case 'light_active':
        alertThreshold = 25.0; // Normal threshold
        contextLabel = 'lúc hoạt động nhẹ';
        break;
      case 'active':
        alertThreshold = 35.0; // Less sensitive during activity
        contextLabel = 'lúc vận động';
        break;
      default:
        alertThreshold = 25.0;
        contextLabel = '';
    }

    if (deviation.abs() > alertThreshold) {
      if (deviation > 0) {
        return 'Nhịp tim cao hơn mức nền ${deviation.toStringAsFixed(1)}% $contextLabel';
      } else {
        return 'Nhịp tim thấp hơn mức nền ${deviation.abs().toStringAsFixed(1)}% $contextLabel';
      }
    }

    return null;
  }

  /// Calculate baseline for SpO2 (less context-dependent than heart rate)
  Future<double> _calculateSpO2Baseline(
    String context,
    DateTime startOfToday,
  ) async {
    final sevenDaysAgo = startOfToday.subtract(const Duration(days: 7));
    final yesterday = startOfToday.subtract(const Duration(days: 1));

    final baselineData = await _database.querySpO2(
      startTime: sevenDaysAgo.millisecondsSinceEpoch,
      endTime: yesterday.millisecondsSinceEpoch,
    );

    if (baselineData.isEmpty) {
      return 97.0; // Healthy default
    }

    // Filter by waking hours for consistent baseline
    final wakingData = baselineData.where((e) {
      final timestamp = e['timestamp'] as int;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final hour = dateTime.hour;
      return hour >= 6 && hour < 23;
    }).toList();

    if (wakingData.isEmpty) {
      return 97.0;
    }

    final values = wakingData.map((e) => e['percentage'] as double).toList();
    return _calculateTrimmedMean(values);
  }

  /// Detect SpO2 anomaly
  String? _detectSpO2Anomaly(double average, double baseline, String context) {
    final deviation = (average - baseline) / baseline * 100;

    // SpO2 is critical - use stricter threshold
    const alertThreshold = 3.0; // 3% deviation is significant for SpO2

    if (deviation.abs() > alertThreshold) {
      if (deviation > 0) {
        // Higher SpO2 is generally not a concern
        return null;
      } else {
        // Lower SpO2 is concerning
        return 'SpO₂ thấp hơn mức nền ${deviation.abs().toStringAsFixed(1)}% - Cần chú ý';
      }
    }

    return null;
  }
}
