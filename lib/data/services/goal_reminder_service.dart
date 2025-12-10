import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service to manage goal reminder notifications
class GoalReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  CollectionReference<Map<String, dynamic>> get _goalsCollection =>
      _firestore.collection('health_goals');

  /// Schedule local notifications for a goal reminder
  Future<void> scheduleGoalReminder({
    required String goalId,
    required String goalTitle,
    required DateTime reminderTime,
  }) async {
    try {
      final notificationId = goalId.hashCode;

      print('📅 Scheduling goal reminder:');
      print('   Goal: $goalTitle');
      print('   Time: $reminderTime');
      print('   ID: $notificationId');

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        reminderTime.year,
        reminderTime.month,
        reminderTime.day,
        reminderTime.hour,
        reminderTime.minute,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        print(
          '⏭️  Đã qua giờ hôm nay, chuyển sang ngày mai: ${scheduledDate.toString()}',
        );
      }

      const androidDetails = AndroidNotificationDetails(
        'goal_reminders',
        'Nhắc mục tiêu',
        channelDescription: 'Thông báo nhắc nhở về mục tiêu sức khỏe',
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

      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Nhắc nhở mục tiêu',
        'Đã đến giờ thực hiện mục tiêu: $goalTitle',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('✅ Đã schedule notification cho mục tiêu: $goalTitle');
    } catch (e) {
      print('❌ Lỗi schedule goal reminder: $e');
      rethrow;
    }
  }

  /// Cancel a goal reminder notification
  Future<void> cancelGoalReminder(String goalId) async {
    try {
      final notificationId = goalId.hashCode;
      await _notificationsPlugin.cancel(notificationId);
      print('🗑️ Đã hủy notification cho goal: $goalId');
    } catch (e) {
      print('❌ Lỗi cancel goal reminder: $e');
    }
  }

  /// Update goal with reminder time
  Future<void> setGoalReminderTime({
    required String goalId,
    required DateTime reminderTime,
    required String goalTitle,
  }) async {
    try {
      // Update Firestore with reminder time
      await _goalsCollection.doc(goalId).update({
        'reminderTime': Timestamp.fromDate(reminderTime),
        'hasReminder': true,
      });

      // Schedule local notification
      await scheduleGoalReminder(
        goalId: goalId,
        goalTitle: goalTitle,
        reminderTime: reminderTime,
      );

      print('✅ Đã set reminder cho goal: $goalTitle');
    } catch (e) {
      print('❌ Lỗi set goal reminder: $e');
      rethrow;
    }
  }

  /// Remove goal reminder
  Future<void> removeGoalReminder(String goalId) async {
    try {
      // Remove from Firestore
      await _goalsCollection.doc(goalId).update({
        'reminderTime': FieldValue.delete(),
        'hasReminder': false,
      });

      // Cancel local notification
      await cancelGoalReminder(goalId);

      print('✅ Đã xóa reminder cho goal: $goalId');
    } catch (e) {
      print('❌ Lỗi remove goal reminder: $e');
      rethrow;
    }
  }

  /// Test notification (fires immediately)
  Future<void> testNotification(String goalTitle) async {
    const androidDetails = AndroidNotificationDetails(
      'goal_reminders',
      'Nhắc mục tiêu',
      channelDescription: 'Thông báo nhắc nhở về mục tiêu sức khỏe',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      999999,
      'Test - Nhắc nhở mục tiêu',
      'Đã đến giờ thực hiện mục tiêu: $goalTitle',
      platformDetails,
    );
  }
}

final goalReminderServiceProvider = Provider<GoalReminderService>((ref) {
  return GoalReminderService();
});
