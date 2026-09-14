import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/models/notification_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/notifications/notifications_view_model.dart';
import '../../providers/user_provider.dart';

class NotificationsListContent extends ConsumerStatefulWidget {
  const NotificationsListContent({super.key});

  @override
  ConsumerState<NotificationsListContent> createState() =>
      _NotificationsListContentState();
}

class _NotificationsListContentState
    extends ConsumerState<NotificationsListContent> {
  final Set<String> _locallyReadIds = <String>{};

  @override
  Widget build(BuildContext context) {
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
        final state = ref.watch(notificationsViewModelProvider(user.uid));
        if (state.loading) return const LoadingWidget();
        if (state.error != null) {
          return Center(child: Text('Lỗi tải thông báo: ${state.error}'));
        }
        final items = state.items;
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
        final vm = ref.read(notificationsViewModelProvider(user.uid).notifier);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final n = items[index];
            final isReadLocal = n.isRead || _locallyReadIds.contains(n.id);
            final icon = _iconForNotification(n.type);
            final iconColor = _colorForNotification(n.type);
            return Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart, // swipe left
              background: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.delete_forever, color: Colors.white)],
                ),
              ),
              confirmDismiss: (direction) async {
                // Optionally ask user? For now always dismiss.
                return true;
              },
              onDismissed: (_) async {
                await vm.delete(n.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xoá thông báo')),
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isReadLocal
                      ? Colors.white
                      : AppColors.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReadLocal
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
                      fontWeight: isReadLocal
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
                        style: const TextStyle(color: AppColors.textSecondary),
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
                  // Tap: mark as read (do not delete; keep item visible)
                  onTap: () async {
                    if (!isReadLocal) {
                      setState(() {
                        _locallyReadIds.add(n.id);
                      });
                      await vm.markAsRead(n.id);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã đánh dấu đã đọc')),
                      );
                    }
                  },
                ),
              ),
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
      case NotificationType.chatMessage:
        return Icons.message;
      case NotificationType.doctorFeedback:
        return Icons.chat_bubble;
      case NotificationType.appointment:
        return Icons.calendar_today;
      case NotificationType.reminder:
        return Icons.access_time;
      case NotificationType.followRequest:
        return Icons.person_add_alt_1;
      case NotificationType.prescription:
        return Icons.medication;
      case NotificationType.other:
        return Icons.notifications;
    }
  }

  Color _colorForNotification(NotificationType type) {
    switch (type) {
      case NotificationType.aiAlert:
        return Colors.red;
      case NotificationType.chatMessage:
        return AppColors.primaryColor;
      case NotificationType.doctorFeedback:
        return AppColors.primaryColor;
      case NotificationType.appointment:
        return AppColors.success;
      case NotificationType.reminder:
        return AppColors.warning;
      case NotificationType.followRequest:
        return Colors.orange;
      case NotificationType.prescription:
        return Colors.green;
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


