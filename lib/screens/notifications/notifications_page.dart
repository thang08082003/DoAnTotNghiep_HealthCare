import 'package:flutter/material.dart';
import '../../components/base_page/base_page_scaffold.dart';
import '../../data/resources/gene/app_colors.dart';

class NotificationsPage extends BasePage {
  const NotificationsPage({
    super.key,
    required super.userRole,
  }) : super(
          title: 'Thông báo',
        );

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends BasePageState<NotificationsPage> {
  final List<Map<String, dynamic>> _notifications = [];
  // TODO: Load notifications from API
  // Future<void> _loadNotifications() async {
  //   final response = await notificationService.getNotifications();
  //   setState(() {
  //     _notifications = response.data;
  //   });
  // }

  @override
  List<Widget> buildPages() {
    return [_buildNotificationsContent()];
  }

  @override
  void onNavigationTap(int index) {
    // Navigation handled by HomePage
  }

  Widget _buildNotificationsContent() {
    return _notifications.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: AppColors.textSecondary),
                SizedBox(height: 16),
                Text(
                  'Không có thông báo nào',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        : ListView.builder(
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              final notification = _notifications[index];
              return _buildNotificationItem(notification);
            },
          );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    IconData icon;
    Color iconColor;

    switch (notification['type']) {
      case 'appointment':
        icon = Icons.calendar_today;
        iconColor = AppColors.primaryColor;
        break;
      case 'result':
        icon = Icons.assignment;
        iconColor = AppColors.success;
        break;
      case 'reminder':
        icon = Icons.access_time;
        iconColor = AppColors.warning;
        break;
      default:
        icon = Icons.notifications;
        iconColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: notification['isRead'] ? Colors.white : AppColors.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification['isRead'] 
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
          notification['title'],
          style: TextStyle(
            fontWeight: notification['isRead'] ? FontWeight.normal : FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['body'],
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              notification['time'],
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        onTap: () {
          setState(() {
            notification['isRead'] = true;
          });
        },
      ),
    );
  }
}