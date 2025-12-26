import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/care_plan_model.dart';

// Provider for CarePlanService
final carePlanServiceProvider = Provider<CarePlanService>((ref) {
  return CarePlanService();
});

class CarePlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CarePlanService();

  // Get tasks for a specific date
  Stream<List<CarePlanTask>> getTasksForDate(String userId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('care_plan_tasks')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('date')
        .orderBy('time')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CarePlanTask.fromFirestore(doc))
              .toList(),
        );
  }

  // Get all health goals
  Stream<List<HealthGoal>> getHealthGoals(String userId) {
    return _firestore
        .collection('health_goals')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HealthGoal.fromFirestore(doc))
              .toList(),
        );
  }

  // Get health goals for a specific date
  Stream<List<HealthGoal>> getHealthGoalsForDate(String userId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('health_goals')
        .where('userId', isEqualTo: userId)
        .where(
          'targetDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('targetDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('targetDate')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HealthGoal.fromFirestore(doc))
              .toList(),
        );
  }

  // ===== Goal Task Methods =====

  // Get tasks for a goal (read-only)
  Stream<List<GoalTask>> getGoalTasks(String goalId) {
    return _firestore
        .collection('goal_tasks')
        .where('goalId', isEqualTo: goalId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => GoalTask.fromFirestore(doc))
              .toList();
        });
  }

  // Get tasks for a specific date (read-only)
  Stream<List<GoalTask>> getGoalTasksForDate(String userId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);

    return _firestore
        .collection('goal_tasks')
        .where('userId', isEqualTo: userId)
        .where(
          'scheduledDates',
          arrayContainsAny: [Timestamp.fromDate(startOfDay)],
        )
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => GoalTask.fromFirestore(doc)).toList(),
        );
  }
}
