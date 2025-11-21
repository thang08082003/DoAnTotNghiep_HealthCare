import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/health_alert_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/health_monitoring_provider.dart';

/// Screen showing all health alerts from patients followed by a doctor
class DoctorPatientAlertsScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const DoctorPatientAlertsScreen({super.key, required this.doctorId});

  @override
  ConsumerState<DoctorPatientAlertsScreen> createState() =>
      _DoctorPatientAlertsScreenState();
}

class _DoctorPatientAlertsScreenState
    extends ConsumerState<DoctorPatientAlertsScreen> {
  final _userRepo = UserRepository();
  final Map<String, UserModel?> _patientCache = {};

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(doctorPatientAlertsProvider(widget.doctorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Cảnh báo bệnh nhân'), elevation: 0),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Lỗi tải cảnh báo',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Không có cảnh báo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chưa có cảnh báo nào trong 24h qua',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(doctorPatientAlertsProvider(widget.doctorId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeader(alerts);
                }
                return _buildAlertCard(alerts[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(List<HealthAlert> alerts) {
    final dangerCount = alerts
        .where((a) => a.level == AlertLevel.danger)
        .length;
    final warningCount = alerts
        .where((a) => a.level == AlertLevel.warning)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dangerCount > 0
              ? [Colors.red[50]!, Colors.red[100]!]
              : [Colors.orange[50]!, Colors.orange[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: dangerCount > 0 ? Colors.red : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alerts.length} cảnh báo trong 24h',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dangerCount nguy hiểm • $warningCount cảnh báo',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(HealthAlert alert) {
    return FutureBuilder<UserModel?>(
      future: _getPatientInfo(alert.userId),
      builder: (context, snapshot) {
        final patient = snapshot.data;
        final patientName = patient?.name ?? 'Bệnh nhân';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _getAlertColor(alert.level).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => _showAlertDetails(alert, patient),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with patient name and level
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _getAlertColor(
                          alert.level,
                        ).withOpacity(0.1),
                        backgroundImage: patient?.avatarUrl != null
                            ? NetworkImage(patient!.avatarUrl!)
                            : null,
                        child: patient?.avatarUrl == null
                            ? Icon(
                                Icons.person,
                                color: _getAlertColor(alert.level),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              _formatTimestamp(alert.timestamp),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildLevelBadge(alert.level),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Alert message
                  Text(
                    alert.message ?? alert.level.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (alert.prediction != null) ...[
                    const SizedBox(height: 12),
                    // Probabilities
                    Row(
                      children: [
                        _buildProbabilityChip(
                          'Nguy hiểm ${(alert.prediction!.probabilityDanger * 100).toStringAsFixed(0)}%',
                          Colors.red,
                        ),
                        const SizedBox(width: 8),
                        _buildProbabilityChip(
                          'Cảnh báo ${(alert.prediction!.probabilityWarning * 100).toStringAsFixed(0)}%',
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelBadge(AlertLevel level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getAlertColor(level).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getAlertIcon(level), size: 14, color: _getAlertColor(level)),
          const SizedBox(width: 4),
          Text(
            level.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getAlertColor(level),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getAlertColor(AlertLevel level) {
    switch (level) {
      case AlertLevel.danger:
        return Colors.red;
      case AlertLevel.warning:
        return Colors.orange;
      case AlertLevel.normal:
        return Colors.green;
    }
  }

  IconData _getAlertIcon(AlertLevel level) {
    switch (level) {
      case AlertLevel.danger:
        return Icons.error;
      case AlertLevel.warning:
        return Icons.warning_amber_rounded;
      case AlertLevel.normal:
        return Icons.check_circle;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }

  Future<UserModel?> _getPatientInfo(String userId) async {
    if (_patientCache.containsKey(userId)) {
      return _patientCache[userId];
    }

    try {
      final patient = await _userRepo.getUserById(userId);
      _patientCache[userId] = patient;
      return patient;
    } catch (e) {
      print('[DoctorPatientAlerts] Error loading patient: $e');
      return null;
    }
  }

  void _showAlertDetails(HealthAlert alert, UserModel? patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Patient info
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: patient?.avatarUrl != null
                        ? NetworkImage(patient!.avatarUrl!)
                        : null,
                    child: patient?.avatarUrl == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient?.name ?? 'Bệnh nhân',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          patient?.email ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildLevelBadge(alert.level),
                ],
              ),
              const SizedBox(height: 24),
              // Timestamp
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(alert.timestamp),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Message
              Text(
                alert.message ?? alert.level.description,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),
              // AI Prediction
              if (alert.prediction != null) ...[
                const Text(
                  'Xác suất AI:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildProbabilityRow(
                  'Bình thường',
                  alert.prediction!.probabilityNormal,
                  AppColors.success,
                ),
                _buildProbabilityRow(
                  'Cảnh báo',
                  alert.prediction!.probabilityWarning,
                  Colors.orange,
                ),
                _buildProbabilityRow(
                  'Nguy hiểm',
                  alert.prediction!.probabilityDanger,
                  Colors.red,
                ),
                const SizedBox(height: 24),
              ],
              // Metrics
              const Text(
                'Chỉ số đo được:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ...alert.metrics.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getMetricName(entry.key),
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        _formatMetricValue(entry.key, entry.value),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProbabilityRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 7,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${(value * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMetricName(String key) {
    const names = {
      'heart_rate': 'Nhịp tim',
      'spo2': 'SpO2',
      'sleep_duration': 'Thời lượng ngủ',
      'sleep_efficiency': 'Hiệu suất ngủ',
      'rem_percent': 'REM',
      'deep_percent': 'Ngủ sâu',
      'awake_minutes': 'Thức giấc',
    };
    return names[key] ?? key;
  }

  String _formatMetricValue(String key, double value) {
    switch (key) {
      case 'heart_rate':
        return '${value.toStringAsFixed(0)} bpm';
      case 'spo2':
      case 'sleep_efficiency':
      case 'rem_percent':
      case 'deep_percent':
        return '${value.toStringAsFixed(1)}%';
      case 'sleep_duration':
        return '${value.toStringAsFixed(1)}h';
      case 'awake_minutes':
        return '${value.toStringAsFixed(0)} phút';
      default:
        return value.toStringAsFixed(1);
    }
  }
}
