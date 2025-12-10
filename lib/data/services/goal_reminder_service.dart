import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to manage goal reminders (Firestore CRUD only)
/// Local notifications are managed by ScheduledNotificationService
class GoalReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _goalsCollection =>
      _firestore.collection('health_goals');

  /// Update goal with reminder time
  Future<void> setGoalReminderTime({
    required String goalId,
    required DateTime reminderTime,
  }) async {
    try {
      await _goalsCollection.doc(goalId).update({
        'reminderTime': Timestamp.fromDate(reminderTime),
        'hasReminder': true,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Remove goal reminder
  Future<void> removeGoalReminder(String goalId) async {
    try {
      await _goalsCollection.doc(goalId).update({
        'reminderTime': FieldValue.delete(),
        'hasReminder': false,
      });
    } catch (e) {
      rethrow;
    }
  }
}

final goalReminderServiceProvider = Provider<GoalReminderService>((ref) {
  return GoalReminderService();
});
