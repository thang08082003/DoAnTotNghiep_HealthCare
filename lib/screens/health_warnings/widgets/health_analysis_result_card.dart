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

          // Sleep
          if (record.sleepAnalysis != null)
            _HealthMetricRow(
              icon: Icons.bedtime,
              label: 'Giấc ngủ',
              value: _formatSleep(record.sleepAnalysis!),
              unit: 'giờ',
            ),
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
    final avgMinutes = data['averageMinutes'] as double;
    return (avgMinutes / 60).toStringAsFixed(1);
  }

  String? _getAnomaly(Map<String, dynamic> data) {
    return data['anomaly'] as String?;
  }

  double? _getBaseline(Map<String, dynamic> data) {
    return data['baseline'] as double?;
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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

  const _AnomalyWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
