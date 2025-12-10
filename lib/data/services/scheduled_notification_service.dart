import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';

/// Service to check and activate scheduled medication reminders
class ScheduledNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _timer;

  /// Start periodic check for scheduled notifications (every minute)
  void startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndActivateScheduledNotifications();
    });
    // Also check immediately
    _checkAndActivateScheduledNotifications();
  }

  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  /// Check for scheduled medication reminders that should be activated now
  Future<void> _checkAndActivateScheduledNotifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final now = DateTime.now();

      // Check medication reminders
      await _checkMedicationReminders(userId, now);

      // Check goal reminders
      await _checkGoalReminders(userId, now);

      // Check task reminders
      await _checkTaskReminders(userId, now);
    } catch (e) {
      print('❌ Lỗi check scheduled notifications: $e');
    }
  }

  /// Check medication reminders
  Future<void> _checkMedicationReminders(String userId, DateTime now) async {
    try {
      // Get active medication reminders
      final remindersSnapshot = await _firestore
          .collection('medication_reminders')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in remindersSnapshot.docs) {
        final data = doc.data();
        final reminderTimes = (data['reminderTimes'] as List<dynamic>?) ?? [];
        final medicationName = data['medicationName'] as String? ?? 'Thuốc';
        final dosage = data['dosage'] as String?;
        final instructions = data['instructions'] as String?;

        for (final timeData in reminderTimes) {
          if (timeData is Map<String, dynamic>) {
            final hour = timeData['hour'] as int?;
            final minute = timeData['minute'] as int?;

            if (hour != null && minute != null) {
              final scheduledTime = DateTime(
                now.year,
                now.month,
                now.day,
                hour,
                minute,
              );

              // Check if this time has just passed (within last minute)
              final diff = now.difference(scheduledTime);
              if (diff.inSeconds >= 0 && diff.inSeconds < 60) {
                // Check if notification already created for this time today
                final notificationKey =
                    '$userId-${doc.id}-${scheduledTime.toString().substring(0, 16)}';

                // Query by notificationKey at top level (not nested in data)
                final existingNotif = await _firestore
                    .collection('notifications')
                    .where('userId', isEqualTo: userId)
                    .where('notificationKey', isEqualTo: notificationKey)
                    .limit(1)
                    .get();

                if (existingNotif.docs.isEmpty) {
                  // Create notification in Firestore
                  await NotificationService.createMedicationReminder(
                    userId: userId,
                    medicationName: medicationName,
                    scheduledTime: scheduledTime,
                    dosage: dosage,
                    instructions: instructions,
                    notificationKey: notificationKey,
                  );

                  print(
                    '✅ Đã tạo notification cho: $medicationName lúc ${hour}:${minute.toString().padLeft(2, '0')}',
                  );
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi check medication reminders: $e');
    }
  }

  /// Check goal reminders
  Future<void> _checkGoalReminders(String userId, DateTime now) async {
    try {
      // Get goals with reminders
      final goalsSnapshot = await _firestore
          .collection('health_goals')
          .where('userId', isEqualTo: userId)
          .where('hasReminder', isEqualTo: true)
          .get();

      for (final doc in goalsSnapshot.docs) {
        final data = doc.data();
        final goalTitle = data['title'] as String? ?? 'Mục tiêu';
        final reminderTime = data['reminderTime'] as Timestamp?;

        if (reminderTime != null) {
          final reminderDate = reminderTime.toDate();
          final scheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            reminderDate.hour,
            reminderDate.minute,
          );

          // Check if this time has just passed (within last minute)
          final diff = now.difference(scheduledTime);

          if (diff.inSeconds >= 0 && diff.inSeconds < 60) {
            // Check if notification already created for this time today
            final notificationKey =
                '$userId-goal-${doc.id}-${scheduledTime.toString().substring(0, 16)}';

            final existingNotif = await _firestore
                .collection('notifications')
                .where('userId', isEqualTo: userId)
                .where('notificationKey', isEqualTo: notificationKey)
                .limit(1)
                .get();

            if (existingNotif.docs.isEmpty) {
              final description = data['description'] as String?;

              // Create notification in Firestore
              await NotificationService.createGoalReminder(
                userId: userId,
                goalTitle: goalTitle,
                scheduledTime: scheduledTime,
                description: description,
                notificationKey: notificationKey,
              );

              print(
                '✅ Goal reminder: $goalTitle lúc ${reminderDate.hour}:${reminderDate.minute.toString().padLeft(2, '0')}',
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi check goal reminders: $e');
    }
  }

  /// Check task reminders
  Future<void> _checkTaskReminders(String userId, DateTime now) async {
    try {
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get tasks for today with notifications enabled
      final tasksSnapshot = await _firestore
          .collection('care_plan_tasks')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('notificationEnabled', isEqualTo: true)
          .get();

      for (final doc in tasksSnapshot.docs) {
        final data = doc.data();
        final taskTitle = data['title'] as String? ?? 'Nhiệm vụ';
        final taskType = data['type'] as String? ?? 'Task';
        final scheduledTime = data['time'] != null
            ? (data['time'] as Timestamp).toDate()
            : null;

        if (scheduledTime != null) {
          final taskDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            scheduledTime.hour,
            scheduledTime.minute,
          );

          // Check if this time has just passed (within last minute)
          final diff = now.difference(taskDateTime);

          if (diff.inSeconds >= 0 && diff.inSeconds < 60) {
            // Check if notification already created
            final notificationKey =
                '$userId-task-${doc.id}-${taskDateTime.toString().substring(0, 16)}';

            final existingNotif = await _firestore
                .collection('notifications')
                .where('userId', isEqualTo: userId)
                .where('notificationKey', isEqualTo: notificationKey)
                .limit(1)
                .get();

            if (existingNotif.docs.isEmpty) {
              final description = data['description'] as String?;

              // Create notification in Firestore
              await NotificationService.createTaskReminder(
                userId: userId,
                taskTitle: taskTitle,
                taskType: taskType,
                scheduledTime: taskDateTime,
                description: description,
                notificationKey: notificationKey,
              );

              print(
                '✅ Task reminder: $taskTitle lúc ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}',
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi check task reminders: $e');
    }
  }

  /// Manual check (can be called when app resumes)
  Future<void> checkNow() async {
    await _checkAndActivateScheduledNotifications();
  }
}

final scheduledNotificationServiceProvider =
    Provider<ScheduledNotificationService>((ref) {
      return ScheduledNotificationService();
    });
