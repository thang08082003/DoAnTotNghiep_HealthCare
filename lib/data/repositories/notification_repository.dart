import '../services/notification_service.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  Stream<List<AppNotification>> watchUserNotifications(String userId) {
    return NotificationService.watchUserNotifications(userId);
  }

  Future<void> markAsRead(String notificationId) {
    return NotificationService.markAsRead(notificationId);
  }

  Future<void> deleteNotification(String notificationId) {
    return NotificationService.deleteNotification(notificationId);
  }
}
