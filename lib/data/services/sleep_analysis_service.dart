/// Service for advanced sleep analysis including:
/// - Scenario A: Deep Sleep < 15% (Poor physical recovery)
/// - Scenario B: REM < 20% (Brain stress)
/// - Scenario C: Light Sleep > 65% (Shallow sleep)
/// - Baseline comparison: Compare against personal 7-day average
class SleepAnalysisService {
  // Medical thresholds (standard)
  static const double deepSleepMinThreshold =
      15.0; // Deep sleep should be >= 15%
  static const double remSleepMinThreshold = 20.0; // REM should be >= 20%
  static const double lightSleepMaxThreshold =
      65.0; // Light sleep should be <= 65%

  // Baseline comparison threshold
  static const double baselineDeviationThreshold =
      20.0; // Alert if deviation > 20%

  /// Analyze sleep quality based on stage percentages
  /// Returns a map with:
  /// - status: 'good', 'warning', or 'poor'
  /// - issues: List of detected issues
  /// - percentages: Calculated percentages for each stage
  /// - recommendations: List of recommendations
  Map<String, dynamic> analyzeSleepQuality({
    required int lightMinutes,
    required int deepMinutes,
    required int remMinutes,
    int? awakeMinutes,
    Map<String, double>? baseline, // 7-day average percentages
  }) {
    // Calculate total sleep time (excluding awake)
    final totalSleepMinutes = lightMinutes + deepMinutes + remMinutes;

    if (totalSleepMinutes == 0) {
      return {
        'status': 'unknown',
        'issues': ['Không có dữ liệu giấc ngủ'],
        'percentages': {'light': 0.0, 'deep': 0.0, 'rem': 0.0},
        'recommendations': [],
        'totalMinutes': 0,
      };
    }

    // Calculate percentages
    final lightPercent = (lightMinutes * 100.0) / totalSleepMinutes;
    final deepPercent = (deepMinutes * 100.0) / totalSleepMinutes;
    final remPercent = (remMinutes * 100.0) / totalSleepMinutes;

    final percentages = {
      'light': lightPercent,
      'deep': deepPercent,
      'rem': remPercent,
    };

    // Detect issues
    final List<String> issues = [];
    final List<String> recommendations = [];
    String status = 'good';

    // Scenario A: Deep Sleep < 15%
    if (deepPercent < deepSleepMinThreshold) {
      status = 'poor';
      issues.add(
        'Giấc ngủ sâu chỉ ${deepPercent.toStringAsFixed(1)}% (dưới ngưỡng ${deepSleepMinThreshold.toStringAsFixed(0)}%)',
      );
      recommendations.add('Phục hồi thể chất kém');
      recommendations.add('Tránh caffeine sau 14h');
      recommendations.add('Tạo môi trường ngủ tối và mát');
    }

    // Scenario B: REM < 20%
    if (remPercent < remSleepMinThreshold) {
      if (status == 'good') status = 'warning';
      issues.add(
        'Giấc ngủ REM chỉ ${remPercent.toStringAsFixed(1)}% (dưới ngưỡng ${remSleepMinThreshold.toStringAsFixed(0)}%)',
      );
      recommendations.add('Não bộ đang căng thẳng');
      recommendations.add('Thực hành giảm stress trước khi ngủ');
      recommendations.add('Tránh màn hình điện tử 1 giờ trước ngủ');
    }

    // Scenario C: Light Sleep > 65%
    if (lightPercent > lightSleepMaxThreshold) {
      if (status == 'good') status = 'warning';
      issues.add(
        'Giấc ngủ nông quá cao: ${lightPercent.toStringAsFixed(1)}% (trên ngưỡng ${lightSleepMaxThreshold.toStringAsFixed(0)}%)',
      );
      recommendations.add('Giấc ngủ quá nông, không đạt hiệu quả phục hồi');
      recommendations.add('Kiểm tra môi trường ngủ (tiếng ồn, nhiệt độ)');
      recommendations.add('Tránh ăn no trước khi ngủ 2-3 giờ');
    }

    // Baseline comparison (if provided)
    if (baseline != null && baseline.isNotEmpty) {
      final baselineIssues = _compareWithBaseline(
        percentages,
        baseline,
        totalSleepMinutes,
      );

      if (baselineIssues.isNotEmpty) {
        if (status == 'good') status = 'warning';
        issues.addAll(baselineIssues);
        recommendations.add(
          'Chất lượng giấc ngủ giảm so với mức trung bình của bạn',
        );
      }
    }

    // If no issues, add positive message
    if (issues.isEmpty) {
      issues.add('Chất lượng giấc ngủ tốt');
      recommendations.add('Duy trì thói quen ngủ hiện tại');
    }

    return {
      'status': status,
      'issues': issues,
      'percentages': percentages,
      'recommendations': recommendations,
      'totalMinutes': totalSleepMinutes,
      'stages': {
        'light': lightMinutes,
        'deep': deepMinutes,
        'rem': remMinutes,
        'awake': awakeMinutes ?? 0,
      },
    };
  }

  /// Compare current sleep with 7-day baseline
  /// Returns list of issues if deviation exceeds threshold
  List<String> _compareWithBaseline(
    Map<String, double> current,
    Map<String, double> baseline,
    int totalMinutes,
  ) {
    final List<String> issues = [];

    // Check deep sleep baseline deviation
    final deepBaseline = baseline['deep'] ?? 0;
    final deepCurrent = current['deep'] ?? 0;
    if (deepBaseline > 0) {
      final deepDeviation = ((deepBaseline - deepCurrent) / deepBaseline) * 100;
      if (deepDeviation > baselineDeviationThreshold) {
        issues.add(
          'Giấc ngủ sâu giảm ${deepDeviation.toStringAsFixed(0)}% so với mức nền (${deepBaseline.toStringAsFixed(1)}%)',
        );
      }
    }

    // Check REM baseline deviation
    final remBaseline = baseline['rem'] ?? 0;
    final remCurrent = current['rem'] ?? 0;
    if (remBaseline > 0) {
      final remDeviation = ((remBaseline - remCurrent) / remBaseline) * 100;
      if (remDeviation > baselineDeviationThreshold) {
        issues.add(
          'Giấc ngủ REM giảm ${remDeviation.toStringAsFixed(0)}% so với mức nền (${remBaseline.toStringAsFixed(1)}%)',
        );
      }
    }

    // Check light sleep baseline deviation (increase is bad)
    final lightBaseline = baseline['light'] ?? 0;
    final lightCurrent = current['light'] ?? 0;
    if (lightBaseline > 0) {
      final lightDeviation =
          ((lightCurrent - lightBaseline) / lightBaseline) * 100;
      if (lightDeviation > baselineDeviationThreshold) {
        issues.add(
          'Giấc ngủ nông tăng ${lightDeviation.toStringAsFixed(0)}% so với mức nền (${lightBaseline.toStringAsFixed(1)}%)',
        );
      }
    }

    return issues;
  }

  /// Calculate baseline (7-day average) for sleep stages
  /// Takes a list of daily sleep data and returns average percentages
  Map<String, double> calculateBaseline(List<Map<String, int>> last7Days) {
    if (last7Days.isEmpty) {
      return {};
    }

    double totalLight = 0;
    double totalDeep = 0;
    double totalRem = 0;
    int validDays = 0;

    for (final day in last7Days) {
      final light = day['light'] ?? 0;
      final deep = day['deep'] ?? 0;
      final rem = day['rem'] ?? 0;
      final total = light + deep + rem;

      if (total > 0) {
        totalLight += (light * 100.0) / total;
        totalDeep += (deep * 100.0) / total;
        totalRem += (rem * 100.0) / total;
        validDays++;
      }
    }

    if (validDays == 0) {
      return {};
    }

    return {
      'light': totalLight / validDays,
      'deep': totalDeep / validDays,
      'rem': totalRem / validDays,
    };
  }

  /// Get a user-friendly status message
  String getStatusMessage(String status) {
    switch (status) {
      case 'good':
        return 'Tốt';
      case 'warning':
        return 'Cảnh báo';
      case 'poor':
        return 'Kém';
      default:
        return 'Không xác định';
    }
  }

  /// Get status color
  String getStatusColor(String status) {
    switch (status) {
      case 'good':
        return 'green';
      case 'warning':
        return 'orange';
      case 'poor':
        return 'red';
      default:
        return 'grey';
    }
  }
}
