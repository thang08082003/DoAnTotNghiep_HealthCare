import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/health_alert_model.dart';
import '../../providers/health_monitoring_provider.dart';
import '../../data/resources/gene/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

final healthAlertsProvider = StreamProvider.family<List<HealthAlert>, String>((
  ref,
  userId,
) {
  final repository = ref.watch(healthAlertRepositoryProvider);
  return repository.getAlertsStream(userId, limit: 50);
});

final autoMonitoringEnabledProvider = StateProvider<bool>((ref) => false);

class HealthAlertsScreen extends ConsumerStatefulWidget {
  final String userId;

  const HealthAlertsScreen({super.key, required this.userId});

  @override
  ConsumerState<HealthAlertsScreen> createState() => _HealthAlertsScreenState();
}

class _HealthAlertsScreenState extends ConsumerState<HealthAlertsScreen> {
  bool _isRunningCheck = false;

  @override
  void initState() {
    super.initState();
    _loadAutoMonitoringState();
  }

  Future<void> _loadAutoMonitoringState() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool('ai_monitoring_enabled_${widget.userId}') ?? false;
    ref.read(autoMonitoringEnabledProvider.notifier).state = enabled;
  }

  Future<void> _toggleAutoMonitoring(bool value) async {
    if (value) {
      await startHealthMonitoring(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã bật cảnh báo tự động (6 giờ/lần)'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      await stopHealthMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Đã tắt cảnh báo tự động'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    ref.read(autoMonitoringEnabledProvider.notifier).state = value;
  }

  Future<void> _runImmediateCheck() async {
    setState(() => _isRunningCheck = true);

    try {
      final result = await runImmediateHealthCheck(widget.userId);
      if (mounted) {
        // Check if sleep data was missing
        final hasSleepData = result?['hasSleepData'] as bool? ?? true;

        if (!hasSleepData) {
          // Show warning about missing sleep data
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Chưa có dữ liệu giấc ngủ\n'
                'Chỉ hiển thị thông tin nhịp tim và SpO2.\n'
                'Kết nối thiết bị theo dõi giấc ngủ để có đánh giá đầy đủ.',
              ),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Phân tích hoàn tất! Kiểm tra kết quả bên dưới'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRunningCheck = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(healthAlertsProvider(widget.userId));
    final autoEnabled = ref.watch(autoMonitoringEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cảnh báo sức khỏe AI'), elevation: 0),
      body: Column(
        children: [
          // Control Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Auto monitoring switch
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.sync,
                          color: AppColors.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cảnh báo tự động',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Phân tích sức khỏe mỗi 6 giờ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: autoEnabled,
                        onChanged: _toggleAutoMonitoring,
                        activeColor: AppColors.primaryColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Manual check button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRunningCheck ? null : _runImmediateCheck,
                    icon: _isRunningCheck
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _isRunningCheck ? 'Đang phân tích...' : 'Phân tích ngay',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Test data button (DEBUG ONLY)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await createTestAlert(widget.userId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Đã tạo cảnh báo test!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Tạo cảnh báo test (DEBUG)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Alerts list
          Expanded(
            child: alertsAsync.when(
              data: (alerts) {
                if (alerts.isEmpty) {
                  return _buildEmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    return _buildAlertCard(alerts[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    const Text('Không thể tải danh sách cảnh báo'),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chưa có cảnh báo nào',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhấn "Phân tích ngay" để kiểm tra sức khỏe',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(HealthAlert alert) {
    final level = alert.level;
    final color = _getAlertColor(level);
    final icon = _getAlertIcon(level);
    final timeAgo = _formatTimeAgo(alert.timestamp);

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Xóa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text('Bạn có chắc muốn xóa cảnh báo này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          final repository = ref.read(healthAlertRepositoryProvider);
          await repository.deleteAlert(alert.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Đã xóa cảnh báo'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Lỗi khi xóa: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: InkWell(
          onTap: () => _showAlertDetails(alert),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!alert.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  alert.message ?? level.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (alert.prediction != null)
                  Row(
                    children: [
                      _buildProbabilityChip(
                        'Nguy hiểm ${(alert.prediction!.probabilityDanger * 100).toStringAsFixed(0)}%',
                        AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      _buildProbabilityChip(
                        'Cảnh báo ${(alert.prediction!.probabilityWarning * 100).toStringAsFixed(0)}%',
                        Colors.orange,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProbabilityChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getAlertColor(AlertLevel level) {
    switch (level) {
      case AlertLevel.normal:
        return AppColors.success;
      case AlertLevel.warning:
        return Colors.orange;
      case AlertLevel.danger:
        return AppColors.error;
    }
  }

  IconData _getAlertIcon(AlertLevel level) {
    switch (level) {
      case AlertLevel.normal:
        return Icons.check_circle;
      case AlertLevel.warning:
        return Icons.warning_amber;
      case AlertLevel.danger:
        return Icons.error;
    }
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }

  void _showAlertDetails(HealthAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getAlertIcon(alert.level),
              color: _getAlertColor(alert.level),
            ),
            const SizedBox(width: 8),
            Text(alert.level.displayName),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                alert.message ?? alert.level.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (alert.prediction != null) ...[
                const Text(
                  'Xác suất AI:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
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
                  AppColors.error,
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  'ℹ️ Thông tin sức khỏe',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chỉ hiển thị các chỉ số hiện có. Cần thêm dữ liệu giấc ngủ để có đánh giá AI đầy đủ.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Chỉ số đo được:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...alert.metrics.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_getMetricName(entry.key)),
                      Text(
                        entry.value.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(alert.timestamp),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityRow(String label, double value, Color color) {
    final percentage = (value * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getMetricName(String key) {
    switch (key) {
      case 'heart_rate':
        return 'Nhịp tim';
      case 'spo2':
        return 'SpO2';
      case 'sleep_duration':
        return 'Giấc ngủ (h)';
      case 'sleep_efficiency':
        return 'Hiệu suất ngủ (%)';
      case 'rem_percent':
        return 'REM (%)';
      case 'deep_percent':
        return 'Giấc sâu (%)';
      case 'awake_minutes':
        return 'Tỉnh giấc (phút)';
      default:
        return key;
    }
  }
}
