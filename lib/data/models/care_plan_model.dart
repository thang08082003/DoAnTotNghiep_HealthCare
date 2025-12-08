import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CarePlanTask {
  final String id;
  final String userId;
  final DateTime date;
  final String title;
  final String? time;
  final bool isCompleted;
  final DateTime createdAt;

  CarePlanTask({
    required this.id,
    required this.userId,
    required this.date,
    required this.title,
    this.time,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory CarePlanTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CarePlanTask(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      title: data['title'] ?? '',
      time: data['time'],
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'title': title,
      'time': time,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class HealthGoal {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime? targetDate;
  final bool isCompleted;
  final DateTime createdAt;

  HealthGoal({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.targetDate,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory HealthGoal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthGoal(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      targetDate: data['targetDate'] != null
          ? (data['targetDate'] as Timestamp).toDate()
          : null,
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// Model cho checklist item
class GoalChecklistItem {
  final String id;
  final String goalId;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final int order;

  GoalChecklistItem({
    required this.id,
    required this.goalId,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.order = 0,
  });

  factory GoalChecklistItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GoalChecklistItem(
      id: doc.id,
      goalId: data['goalId'] ?? '',
      title: data['title'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'goalId': goalId,
      'title': title,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'order': order,
    };
  }
}

// Model cho task (việc cần làm: uống thuốc, đo huyết áp, etc.)
class GoalTask {
  final String id;
  final String goalId;
  final String userId;
  final String title;
  final String? description;
  final List<DateTime> scheduledDates; // Các ngày cần thực hiện
  final String? scheduledTime; // Giờ thực hiện (HH:mm format)
  final bool notificationEnabled;
  final TaskType type;
  final bool isCompleted;
  final DateTime createdAt;

  GoalTask({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.title,
    this.description,
    required this.scheduledDates,
    this.scheduledTime,
    this.notificationEnabled = true,
    required this.type,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory GoalTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GoalTask(
      id: doc.id,
      goalId: data['goalId'] ?? '',
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      scheduledDates:
          (data['scheduledDates'] as List<dynamic>?)
              ?.map((timestamp) => (timestamp as Timestamp).toDate())
              .toList() ??
          [],
      scheduledTime: data['scheduledTime'],
      notificationEnabled: data['notificationEnabled'] ?? true,
      type: TaskType.values.firstWhere(
        (e) => e.toString() == 'TaskType.${data['type']}',
        orElse: () => TaskType.other,
      ),
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'goalId': goalId,
      'userId': userId,
      'title': title,
      'description': description,
      'scheduledDates': scheduledDates
          .map((date) => Timestamp.fromDate(date))
          .toList(),
      'scheduledTime': scheduledTime,
      'notificationEnabled': notificationEnabled,
      'type': type.name,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  GoalTask copyWith({
    String? id,
    String? goalId,
    String? userId,
    String? title,
    String? description,
    List<DateTime>? scheduledDates,
    String? scheduledTime,
    bool? notificationEnabled,
    TaskType? type,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return GoalTask(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDates: scheduledDates ?? this.scheduledDates,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      type: type ?? this.type,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Enum cho loại task
enum TaskType {
  medication, // Uống thuốc
  bloodPressure, // Đo huyết áp
  bloodSugar, // Đo đường huyết
  exercise, // Tập thể dục
  diet, // Chế độ ăn
  checkup, // Khám bệnh
  other, // Khác
}

// Extension để hiển thị tên task type bằng tiếng Việt
extension TaskTypeExtension on TaskType {
  String get displayName {
    switch (this) {
      case TaskType.medication:
        return 'Uống thuốc';
      case TaskType.bloodPressure:
        return 'Đo huyết áp';
      case TaskType.bloodSugar:
        return 'Đo đường huyết';
      case TaskType.exercise:
        return 'Tập thể dục';
      case TaskType.diet:
        return 'Chế độ ăn';
      case TaskType.checkup:
        return 'Khám bệnh';
      case TaskType.other:
        return 'Khác';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskType.medication:
        return Icons.medication;
      case TaskType.bloodPressure:
        return Icons.favorite;
      case TaskType.bloodSugar:
        return Icons.water_drop;
      case TaskType.exercise:
        return Icons.fitness_center;
      case TaskType.diet:
        return Icons.restaurant;
      case TaskType.checkup:
        return Icons.local_hospital;
      case TaskType.other:
        return Icons.task_alt;
    }
  }
}
