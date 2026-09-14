import 'package:flutter/material.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../data/models/health_analysis_record.dart';

class HealthAnalysisResultCard extends StatelessWidget {
  final HealthAnalysisRecord record;

  const HealthAnalysisResultCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kết quả phân tích',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                _formatTime(record.timestamp),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Heart Rate
          if (record.heartRateAnalysis != null) ...[
            _HealthMetricRow(
              icon: Icons.favorite,
              label: 'Nhịp tim',
              value: _formatHeartRate(record.heartRateAnalysis!),
              unit: 'BPM',
            ),
            if (_getBaseline(record.heartRateAnalysis!) != null) ...[
              const SizedBox(height: 4),
              _BaselineInfo(
                baseline: _getBaseline(record.heartRateAnalysis!)!,
                unit: 'BPM',
              ),
            ],
            if (_getAnomaly(record.heartRateAnalysis!) != null) ...[
              const SizedBox(height: 8),
              _AnomalyWarning(message: _getAnomaly(record.heartRateAnalysis!)!),
            ],
          ],

          if (record.heartRateAnalysis != null &&
              (record.spo2Analysis != null || record.sleepAnalysis != null))
            const Divider(height: 24),

          // SpO2
          if (record.spo2Analysis != null) ...[
            _HealthMetricRow(
              icon: Icons.bloodtype,
              label: 'SpO₂',
              value: _formatSpO2(record.spo2Analysis!),
              unit: '%',
            ),
            if (_getBaseline(record.spo2Analysis!) != null) ...[
              const SizedBox(height: 4),
              _BaselineInfo(
                baseline: _getBaseline(record.spo2Analysis!)!,
                unit: '%',
              ),
            ],
            if (_getAnomaly(record.spo2Analysis!) != null) ...[
              const SizedBox(height: 8),
              _AnomalyWarning(message: _getAnomaly(record.spo2Analysis!)!),
            ],
          ],

          if (record.spo2Analysis != null && record.sleepAnalysis != null)
            const Divider(height: 24),

          // Sleep - Enhanced with detailed analysis
          if (record.sleepAnalysis != null) ...[
            _HealthMetricRow(
              icon: Icons.bedtime,
              label: 'Giấc ngủ',
              value: _formatSleep(record.sleepAnalysis!),
              unit: 'giờ',
            ),

            // Sleep quality status
            if (record.sleepAnalysis!['status'] != null) ...[
              const SizedBox(height: 12),
              _SleepStatusBadge(
                status: record.sleepAnalysis!['status'] as String,
              ),
            ],

            // Sleep stage percentages
            if (record.sleepAnalysis!['percentages'] != null) ...[
              const SizedBox(height: 12),
              _SleepStagePercentages(
                percentages:
                    record.sleepAnalysis!['percentages']
                        as Map<String, dynamic>,
              ),
            ],

            // Issues and warnings
            if (record.sleepAnalysis!['issues'] != null) ...[
              const SizedBox(height: 12),
              ..._buildSleepIssues(record.sleepAnalysis!['issues'] as List),
            ],

            // Recommendations
            if (record.sleepAnalysis!['recommendations'] != null &&
                (record.sleepAnalysis!['recommendations'] as List)
                    .isNotEmpty) ...[
              const SizedBox(height: 12),
              _SleepRecommendations(
                recommendations:
                    record.sleepAnalysis!['recommendations'] as List,
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatHeartRate(Map<String, dynamic> data) {
    final count = data['count'] as int;
    if (count == 0) return '--';
    final average = data['average'] as double;
    return average.toStringAsFixed(0);
  }

  String _formatSpO2(Map<String, dynamic> data) {
    final count = data['count'] as int;
    if (count == 0) return '--';
    final average = data['average'] as double;
    return average.toStringAsFixed(1);
  }

  String _formatSleep(Map<String, dynamic> data) {
    final count = data['count'] as int;
    if (count == 0) return '--';
    // Show total sleep duration of the day instead of per-session average
    final totalMinutes = (data['totalMinutes'] as num).toDouble();
    return (totalMinutes / 60).toStringAsFixed(1);
  }

  String? _getAnomaly(Map<String, dynamic> data) {
    return data['anomaly'] as String?;
  }

  double? _getBaseline(Map<String, dynamic> data) {
    return data['baseline'] as double?;
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildSleepIssues(List issues) {
    return issues.map((issue) {
      final issueText = issue.toString();
      // Determine severity based on keywords
      final isError =
          issueText.contains('kém') ||
          issueText.contains('căng thẳng') ||
          issueText.contains('quá nông');

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _AnomalyWarning(
          message: issueText,
          severity: isError ? 'error' : 'warning',
        ),
      );
    }).toList();
  }
}

class _HealthMetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const _HealthMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          unit,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _BaselineInfo extends StatelessWidget {
  final double baseline;
  final String unit;

  const _BaselineInfo({required this.baseline, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Text(
        'Mức nền: ${baseline.toStringAsFixed(1)} $unit',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _AnomalyWarning extends StatelessWidget {
  final String message;
  final String severity; // 'warning' or 'error'

  const _AnomalyWarning({required this.message, this.severity = 'warning'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// New widgets for enhanced sleep analysis
class _SleepStatusBadge extends StatelessWidget {
  final String status;

  const _SleepStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String displayText;

    switch (status) {
      case 'good':
        displayText = 'Tốt';
        break;
      case 'warning':
        displayText = 'Cảnh báo';
        break;
      case 'poor':
        displayText = 'Kém';
        break;
      default:
        displayText = 'Không xác định';
    }

    return Text(
      'Chất lượng: $displayText',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _SleepStagePercentages extends StatelessWidget {
  final Map<String, dynamic> percentages;

  const _SleepStagePercentages({required this.percentages});

  @override
  Widget build(BuildContext context) {
    final light = (percentages['light'] as double?) ?? 0;
    final deep = (percentages['deep'] as double?) ?? 0;
    final rem = (percentages['rem'] as double?) ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giai đoạn giấc ngủ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _StageRow(
            label: 'Ngủ nông (Light)',
            percentage: light,
            color: const Color(0xFF90CAF9),
          ),
          const SizedBox(height: 6),
          _StageRow(
            label: 'Ngủ sâu (Deep)',
            percentage: deep,
            color: const Color(0xFF80CBC4),
          ),
          const SizedBox(height: 6),
          _StageRow(
            label: 'Ngủ REM',
            percentage: rem,
            color: const Color(0xFFCE93D8),
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;

  const _StageRow({
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SleepRecommendations extends StatelessWidget {
  final List recommendations;

  const _SleepRecommendations({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppColors.textSecondary,
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                'Khuyến nghị',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rec.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
