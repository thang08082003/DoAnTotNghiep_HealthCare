import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/health_alert_model.dart';
import '../../providers/health_monitoring_provider.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../screens/health_alerts/health_alerts_screen.dart';
import 'package:intl/intl.dart';

final latestHealthAlertProvider = StreamProvider.family<HealthAlert?, String>((
  ref,
  userId,
) {
  final repository = ref.watch(healthAlertRepositoryProvider);
  return repository
      .getAlertsStream(userId, limit: 1)
      .map((alerts) => alerts.isEmpty ? null : alerts.first);
});

class LatestHealthAlertWidget extends ConsumerWidget {
  final String userId;

  const LatestHealthAlertWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertAsync = ref.watch(latestHealthAlertProvider(userId));

    return alertAsync.when(
      data: (alert) {
        if (alert == null) {
          return _buildNoAlertCard(context);
        }
        return _buildAlertCard(context, alert);
      },
      loading: () {
        return _buildLoadingCard(context);
      },
      error: (error, stack) {
        return _buildErrorCard(context);
      },
    );
  }

  Widget _buildNoAlertCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        try {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HealthAlertsScreen(userId: userId),
            ),
          );
        } catch (e) {
          // Silently catch navigation errors
        }
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Không có cảnh báo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Các chỉ số sức khỏe đều ổn định',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, HealthAlert alert) {
    final level = alert.level;
    final color = _getAlertColor(level);
    final icon = _getAlertIcon(level);
    final timeAgo = _formatTimeAgo(alert.timestamp);

    return GestureDetector(
      onTap: () {
        try {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HealthAlertsScreen(userId: userId),
            ),
          );
        } catch (e) {
          // Silently catch navigation errors
        }
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Cảnh báo AI: ${level.displayName}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
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
                        const SizedBox(height: 4),
                        Text(
                          alert.message ?? level.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (alert.prediction != null) ...[
                    _buildProbabilityChip(
                      'Nguy hiểm: ${(alert.prediction!.probabilityDanger * 100).toStringAsFixed(0)}%',
                      Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _buildProbabilityChip(
                      'Cảnh báo: ${(alert.prediction!.probabilityWarning * 100).toStringAsFixed(0)}%',
                      Colors.orange,
                    ),
                  ],
                ],
              ),
            ],
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

  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        try {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HealthAlertsScreen(userId: userId),
            ),
          );
        } catch (e) {
          // Silently catch navigation errors
        }
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Không thể tải cảnh báo',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
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
}
