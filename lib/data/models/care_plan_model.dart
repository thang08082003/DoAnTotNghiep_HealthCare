import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Enum cho trạng thái health goal (giống prescription)
enum HealthGoalStatus {
  pendingPatientReview, // Chờ bệnh nhân xem & phản hồi
  approvedByPatient, // Bệnh nhân đã chấp nhận
  rejected, // Bệnh nhân từ chối
  modificationRequested, // Bệnh nhân yêu cầu chỉnh sửa
  active, // Đang hoạt động (sau khi approve)
  completed, // Hoàn thành
}

extension HealthGoalStatusExtension on HealthGoalStatus {
  String get displayName {
    switch (this) {
      case HealthGoalStatus.pendingPatientReview:
        return 'Chờ xem & phản hồi';
      case HealthGoalStatus.approvedByPatient:
        return 'Đã chấp nhận';
      case HealthGoalStatus.rejected:
        return 'Từ chối';
      case HealthGoalStatus.modificationRequested:
        return 'Yêu cầu chỉnh sửa';
      case HealthGoalStatus.active:
        return 'Đang thực hiện';
      case HealthGoalStatus.completed:
        return 'Hoàn thành';
    }
  }

  String get value {
    return toString().split('.').last;
  }

  static HealthGoalStatus fromString(String value) {
    return HealthGoalStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HealthGoalStatus.pendingPatientReview,
    );
  }
}

// Enum cho loại mục tiêu
enum HealthGoalType {
  medication, // Lịch uống thuốc từ đơn thuốc (auto-created)
  measurement, // Đo chỉ số (huyết áp, đường huyết, cân nặng...)
  exercise, // Tập thể dục
  diet, // Chế độ ăn uống
  checkup, // Lịch tái khám
  reminder, // Nhắc nhở khác
  other, // Khác
}

// Extension hiển thị tên tiếng Việt
extension HealthGoalTypeExtension on HealthGoalType {
  String get displayName {
    switch (this) {
      case HealthGoalType.medication:
        return 'Uống thuốc';
      case HealthGoalType.measurement:
        return 'Đo chỉ số';
      case HealthGoalType.exercise:
        return 'Tập thể dục';
      case HealthGoalType.diet:
        return 'Chế độ ăn';
      case HealthGoalType.checkup:
        return 'Tái khám';
      case HealthGoalType.reminder:
        return 'Nhắc nhở';
      case HealthGoalType.other:
        return 'Khác';
    }
  }

  IconData get icon {
    switch (this) {
      case HealthGoalType.medication:
        return Icons.medication;
      case HealthGoalType.measurement:
        return Icons.monitor_heart;
      case HealthGoalType.exercise:
        return Icons.fitness_center;
      case HealthGoalType.diet:
        return Icons.restaurant;
      case HealthGoalType.checkup:
        return Icons.event_note;
      case HealthGoalType.reminder:
        return Icons.notifications_active;
      case HealthGoalType.other:
        return Icons.task_alt;
    }
  }

  Color get color {
    switch (this) {
      case HealthGoalType.medication:
        return Colors.blue;
      case HealthGoalType.measurement:
        return Colors.red;
      case HealthGoalType.exercise:
        return Colors.green;
      case HealthGoalType.diet:
        return Colors.orange;
      case HealthGoalType.checkup:
        return Colors.purple;
      case HealthGoalType.reminder:
        return Colors.amber;
      case HealthGoalType.other:
        return Colors.grey;
    }
  }
}

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
  final String userId; // Patient ID
  final String? doctorId; // Doctor who created this goal
  final String title;
  final String? description;
  final DateTime? targetDate;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? reminderTime;
  final bool hasReminder;

  // Goal type
  final HealthGoalType type;

  // Medication-specific fields (when type = medication)
  final String? prescriptionId; // Link to MedicationPrescription
  final List<String>? reminderTimes; // Multiple reminder times (HH:mm format)
  final String? medicationName; // Tên thuốc (copied from prescription)
  final String? dosage; // Liều dùng (copied from prescription)
  final String? timing; // Thời điểm dùng (copied from prescription)

  // Measurement-specific fields (when type = measurement)
  final String? measurementType; // 'blood_pressure', 'blood_sugar', 'weight'...
  final String? targetValue; // VD: '120/80', '<100mg/dL', '65kg'
  final String? frequency; // 'daily', 'twice_daily', 'weekly'

  // Approval workflow (giống prescription system)
  final HealthGoalStatus status;
  final String?
  patientResponse; // Phản hồi của bệnh nhân (lý do từ chối/yêu cầu sửa)
  final int modificationRequestCount; // Số lần yêu cầu chỉnh sửa
  final bool requiresVideoCall; // Cần gọi video để giải quyết
  final bool
  isFinalEdit; // Đã video call, bác sĩ sửa lần cuối, patient chỉ được accept/reject
  final DateTime? updatedAt;

  HealthGoal({
    required this.id,
    required this.userId,
    this.doctorId,
    required this.title,
    this.description,
    this.targetDate,
    this.isCompleted = false,
    required this.createdAt,
    this.reminderTime,
    this.hasReminder = false,
    this.type = HealthGoalType.other,
    this.prescriptionId,
    this.reminderTimes,
    this.medicationName,
    this.dosage,
    this.timing,
    this.measurementType,
    this.targetValue,
    this.frequency,
    this.status = HealthGoalStatus.pendingPatientReview,
    this.patientResponse,
    this.modificationRequestCount = 0,
    this.requiresVideoCall = false,
    this.isFinalEdit = false,
    this.updatedAt,
  });

  factory HealthGoal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse type (always medication now)
    HealthGoalType type = HealthGoalType.medication;
    if (data['type'] != null) {
      try {
        type = HealthGoalType.values.firstWhere(
          (e) => e.toString() == 'HealthGoalType.${data['type']}',
          orElse: () => HealthGoalType.medication,
        );
      } catch (e) {
        type = HealthGoalType.medication;
      }
    }

    return HealthGoal(
      id: doc.id,
      userId: data['userId'] ?? '',
      doctorId: data['doctorId'],
      title: data['title'] ?? '',
      description: data['description'],
      targetDate: data['targetDate'] != null
          ? (data['targetDate'] as Timestamp).toDate()
          : null,
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      reminderTime: data['reminderTime'] != null
          ? (data['reminderTime'] as Timestamp).toDate()
          : null,
      hasReminder: data['hasReminder'] ?? false,
      type: type,
      prescriptionId: data['prescriptionId'],
      reminderTimes: data['reminderTimes'] != null
          ? List<String>.from(data['reminderTimes'])
          : null,
      medicationName: data['medicationName'],
      dosage: data['dosage'],
      timing: data['timing'],
      measurementType: data['measurementType'],
      targetValue: data['targetValue'],
      frequency: data['frequency'],
      status: HealthGoalStatusExtension.fromString(
        data['status'] ?? 'pendingPatientReview',
      ),
      patientResponse: data['patientResponse'],
      modificationRequestCount: data['modificationRequestCount'] ?? 0,
      requiresVideoCall: data['requiresVideoCall'] ?? false,
      isFinalEdit: data['isFinalEdit'] ?? false,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'doctorId': doctorId,
      'title': title,
      'description': description,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'reminderTime': reminderTime != null
          ? Timestamp.fromDate(reminderTime!)
          : null,
      'hasReminder': hasReminder,
      'type': type.name,
      'prescriptionId': prescriptionId,
      'reminderTimes': reminderTimes,
      'medicationName': medicationName,
      'dosage': dosage,
      'timing': timing,
      'measurementType': measurementType,
      'targetValue': targetValue,
      'frequency': frequency,
      'status': status.value,
      'patientResponse': patientResponse,
      'modificationRequestCount': modificationRequestCount,
      'requiresVideoCall': requiresVideoCall,
      'isFinalEdit': isFinalEdit,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
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
