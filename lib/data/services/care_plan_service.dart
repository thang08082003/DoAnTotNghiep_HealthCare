import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/care_plan_model.dart';
import 'task_reminder_service.dart';

// Provider for CarePlanService
final carePlanServiceProvider = Provider<CarePlanService>((ref) {
  final reminderService = ref.watch(taskReminderServiceProvider);
  return CarePlanService(reminderService);
});

class CarePlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TaskReminderService _reminderService;

  CarePlanService(this._reminderService);

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

  // Create a new health goal
  Future<void> createHealthGoal({
    required String userId,
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final goal = HealthGoal(
      id: '',
      userId: userId,
      title: title,
      description: description,
      targetDate: targetDate,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
    await _firestore.collection('health_goals').add(goal.toFirestore());
  }

  // Update health goal
  Future<void> updateHealthGoal(
    String goalId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore.collection('health_goals').doc(goalId).update(updates);
  }

  // Delete health goal
  Future<void> deleteHealthGoal(String goalId) async {
    await _firestore.collection('health_goals').doc(goalId).delete();
  }

  // Toggle goal completion
  Future<void> toggleGoalCompletion(String goalId, bool isCompleted) async {
    await _firestore.collection('health_goals').doc(goalId).update({
      'isCompleted': isCompleted,
    });
  }

  // ===== Goal Task Methods =====

  // Get tasks for a goal
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

  // Get tasks for a specific date
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

  // Create goal task
  Future<void> createGoalTask({
    required String goalId,
    required String userId,
    required String title,
    String? description,
    required List<DateTime> scheduledDates,
    String? scheduledTime,
    required TaskType type,
    bool notificationEnabled = true,
  }) async {
    final task = GoalTask(
      id: '',
      goalId: goalId,
      userId: userId,
      title: title,
      description: description,
      scheduledDates: scheduledDates,
      scheduledTime: scheduledTime,
      notificationEnabled: notificationEnabled,
      type: type,
      isCompleted: false,
      createdAt: DateTime.now(),
    );

    final taskData = task.toFirestore();
    final docRef = await _firestore.collection('goal_tasks').add(taskData);

    // Schedule reminders if enabled
    if (notificationEnabled) {
      final taskWithId = task.copyWith(id: docRef.id);
      await _reminderService.scheduleTaskReminders(taskWithId);
    }
  }

  // Toggle task completion
  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) async {
    await _firestore.collection('goal_tasks').doc(taskId).update({
      'isCompleted': isCompleted,
    });

    // Cancel reminders when task is completed
    if (isCompleted) {
      // Get task to know how many dates to cancel
      final doc = await _firestore.collection('goal_tasks').doc(taskId).get();
      if (doc.exists) {
        final task = GoalTask.fromFirestore(doc);
        await _reminderService.cancelTaskReminders(
          taskId,
          task.scheduledDates.length,
        );
      }
    }
  }

  // Delete task
  Future<void> deleteGoalTask(String taskId) async {
    try {
      // Get task to know how many dates to cancel
      final doc = await _firestore.collection('goal_tasks').doc(taskId).get();
      if (doc.exists) {
        final task = GoalTask.fromFirestore(doc);
        // Cancel all reminders first
        await _reminderService.cancelTaskReminders(
          taskId,
          task.scheduledDates.length,
        );
      }

      await _firestore.collection('goal_tasks').doc(taskId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Update task
  Future<void> updateGoalTask(
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    // Get old task data
    final doc = await _firestore.collection('goal_tasks').doc(taskId).get();
    final oldTask = doc.exists ? GoalTask.fromFirestore(doc) : null;
    final oldDateCount = oldTask?.scheduledDates.length ?? 0;

    await _firestore.collection('goal_tasks').doc(taskId).update(updates);

    // Update reminders if notification settings or dates changed
    if (oldTask != null) {
      final updatedDoc = await _firestore
          .collection('goal_tasks')
          .doc(taskId)
          .get();
      if (updatedDoc.exists) {
        final updatedTask = GoalTask.fromFirestore(updatedDoc);
        await _reminderService.updateTaskReminders(updatedTask, oldDateCount);
      }
    }
  }
}
