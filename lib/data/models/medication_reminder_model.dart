import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// Model cho lịch nhắc thuốc
class MedicationReminder {
  final String id;
  final String medicationId;
  final String userId;
  final String medicationName;
  final List<ReminderTime> reminderTimes; // Các mốc thời gian nhắc trong ngày
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastNotifiedAt; // Lần nhắc gần nhất

  MedicationReminder({
    required this.id,
    required this.medicationId,
    required this.userId,
    required this.medicationName,
    required this.reminderTimes,
    this.isActive = true,
    required this.createdAt,
    this.lastNotifiedAt,
  });

  factory MedicationReminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final times =
        (data['reminderTimes'] as List<dynamic>?)
            ?.map(
              (t) => ReminderTime(
                hour: t['hour'] as int,
                minute: t['minute'] as int,
              ),
            )
            .toList() ??
        [];

    return MedicationReminder(
      id: doc.id,
      medicationId: data['medicationId'] ?? '',
      userId: data['userId'] ?? '',
      medicationName: data['medicationName'] ?? '',
      reminderTimes: times,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastNotifiedAt: data['lastNotifiedAt'] != null
          ? (data['lastNotifiedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'medicationId': medicationId,
      'userId': userId,
      'medicationName': medicationName,
      'reminderTimes': reminderTimes
          .map((t) => {'hour': t.hour, 'minute': t.minute})
          .toList(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastNotifiedAt': lastNotifiedAt != null
          ? Timestamp.fromDate(lastNotifiedAt!)
          : null,
    };
  }

  MedicationReminder copyWith({
    String? id,
    String? medicationId,
    String? userId,
    String? medicationName,
    List<ReminderTime>? reminderTimes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastNotifiedAt,
  }) {
    return MedicationReminder(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      userId: userId ?? this.userId,
      medicationName: medicationName ?? this.medicationName,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
    );
  }

  /// Tạo notification ID duy nhất cho mỗi lần nhắc
  int notificationId(ReminderTime time) {
    final combined = '$medicationId-${time.hour}-${time.minute}';
    return combined.hashCode.abs() % 2147483647; // Max int32
  }

  /// Convert Flutter TimeOfDay to ReminderTime
  static ReminderTime fromTimeOfDay(TimeOfDay time) {
    return ReminderTime(hour: time.hour, minute: time.minute);
  }
}

/// Custom time class to avoid conflict with Flutter's TimeOfDay
class ReminderTime {
  final int hour;
  final int minute;

  const ReminderTime({required this.hour, required this.minute});

  /// Convert to Flutter's TimeOfDay
  TimeOfDay toTimeOfDay() {
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  String toString() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderTime &&
        other.hour == hour &&
        other.minute == minute;
  }

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}
