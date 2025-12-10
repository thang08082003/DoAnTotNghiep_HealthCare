import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/care_plan_model.dart';
import '../../providers/health_monitoring_provider.dart';

/// Service quản lý nhắc nhở cho goal tasks
class TaskReminderService {
  final FlutterLocalNotificationsPlugin _notifications;

  TaskReminderService(this._notifications);

  /// Tạo notification ID từ task ID
  int _notificationId(String taskId) {
    return taskId.hashCode.abs() % 2147483647;
  }

  /// Lên lịch nhắc nhở cho một task (schedule cho tất cả scheduledDates)
  Future<void> scheduleTaskReminders(GoalTask task) async {
    if (!task.notificationEnabled || task.scheduledDates.isEmpty) return;

    // Lên lịch cho mỗi ngày trong scheduledDates
    for (int i = 0; i < task.scheduledDates.length; i++) {
      await _scheduleTaskReminderForDate(task, task.scheduledDates[i], i);
    }
  }

  /// Lên lịch nhắc nhở cho một task vào một ngày cụ thể
  Future<void> _scheduleTaskReminderForDate(
    GoalTask task,
    DateTime date,
    int index,
  ) async {
    try {
      tz.TZDateTime scheduledTime;

      if (task.scheduledTime != null) {
        // Parse time string (HH:mm format)
        final timeParts = task.scheduledTime!.split(':');
        if (timeParts.length == 2) {
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);

          scheduledTime = tz.TZDateTime(
            tz.local,
            date.year,
            date.month,
            date.day,
            hour,
            minute,
          );
        } else {
          scheduledTime = tz.TZDateTime.from(date, tz.local);
        }
      } else {
        scheduledTime = tz.TZDateTime.from(date, tz.local);
      }

      // Nếu thời gian đã qua, không schedule
      if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'goal_task_reminders',
        'Nhắc việc cần làm',
        channelDescription:
            'Thông báo nhắc nhở các việc cần làm trong kế hoạch',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Unique ID cho mỗi task + date combination
      final notificationId = _notificationId('${task.id}_$index');

      await _notifications.zonedSchedule(
        notificationId,
        '📋 ${task.type.displayName}: ${task.title}',
        task.description ?? 'Đã đến thời gian thực hiện',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Silently catch scheduling errors
    }
  }

  /// Hủy tất cả nhắc nhở của một task
  Future<void> cancelTaskReminders(String taskId, int dateCount) async {
    try {
      for (int i = 0; i < dateCount; i++) {
        final notificationId = _notificationId('${taskId}_$i');
        await _notifications.cancel(notificationId);
      }
    } catch (e) {
      // Silently catch cancel errors
    }
  }

  /// Cập nhật nhắc nhở (hủy cũ và tạo mới)
  Future<void> updateTaskReminders(GoalTask task, int oldDateCount) async {
    await cancelTaskReminders(task.id, oldDateCount);
    if (!task.isCompleted) {
      await scheduleTaskReminders(task);
    }
  }
}

/// Provider
final taskReminderServiceProvider = Provider<TaskReminderService>((ref) {
  final notifications = ref.watch(localNotificationsProvider);
  return TaskReminderService(notifications);
});
