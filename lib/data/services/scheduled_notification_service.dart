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
    } catch (e) {
      // Silently catch errors
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
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // Silently catch medication reminder errors
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
            }
          }
        }
      }
    } catch (e) {
      // Silently catch goal reminder errors
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
