import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/models/notification_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/notification_service.dart';
import '../../providers/user_provider.dart';

class NotificationsListContent extends ConsumerWidget {
  const NotificationsListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, st) => Center(child: Text('Lỗi tải người dùng: $e')),
      data: (user) {
        if (user == null) {
          return const Center(
            child: Text('Vui lòng đăng nhập để xem thông báo'),
          );
        }
        return StreamBuilder<List<AppNotification>>(
          stream: NotificationService.watchUserNotifications(user.uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingWidget();
            }
            if (snap.hasError) {
              return Center(child: Text('Lỗi tải thông báo: ${snap.error}'));
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Chưa có thông báo nào',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final n = items[index];
                final icon = _iconForNotification(n.type);
                final iconColor = _colorForNotification(n.type);
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: n.isRead
                        ? Colors.white
                        : AppColors.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: n.isRead
                          ? Colors.grey.withValues(alpha: 0.2)
                          : AppColors.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          n.body,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(n.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      if (!n.isRead) {
                        await NotificationService.markAsRead(n.id);
                      }
                      // Optional: handle deep links by type
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  IconData _iconForNotification(NotificationType type) {
    switch (type) {
      case NotificationType.aiAlert:
        return Icons.bolt;
      case NotificationType.doctorFeedback:
        return Icons.chat_bubble;
      case NotificationType.appointment:
        return Icons.calendar_today;
      case NotificationType.reminder:
        return Icons.access_time;
      case NotificationType.other:
        return Icons.notifications;
    }
  }

  Color _colorForNotification(NotificationType type) {
    switch (type) {
      case NotificationType.aiAlert:
        return Colors.red;
      case NotificationType.doctorFeedback:
        return AppColors.primaryColor;
      case NotificationType.appointment:
        return AppColors.success;
      case NotificationType.reminder:
        return AppColors.warning;
      case NotificationType.other:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
