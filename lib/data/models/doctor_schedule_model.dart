import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a time slot for appointments
class TimeSlot {
  final String startTime; // e.g., "08:00"
  final String endTime;   // e.g., "08:30"
  final bool isAvailable;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: json['startTime'] ?? json['start_time'] ?? '',
      endTime: json['endTime'] ?? json['end_time'] ?? '',
      isAvailable: json['isAvailable'] ?? json['is_available'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
    };
  }

  @override
  String toString() => '$startTime - $endTime';
}

/// Model representing a doctor's working day schedule
class DaySchedule {
  final String dayOfWeek; // e.g., "monday", "tuesday", etc.
  final bool isWorkingDay;
  final List<TimeSlot> timeSlots;

  DaySchedule({
    required this.dayOfWeek,
    this.isWorkingDay = false,
    this.timeSlots = const [],
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    final slots = json['timeSlots'] ?? json['time_slots'] ?? json['slots'] ?? [];
    return DaySchedule(
      dayOfWeek: json['dayOfWeek'] ?? json['day_of_week'] ?? json['day'] ?? '',
      isWorkingDay: json['isWorkingDay'] ?? json['is_working_day'] ?? json['isWorking'] ?? false,
      timeSlots: (slots as List)
          .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'isWorkingDay': isWorkingDay,
      'timeSlots': timeSlots.map((s) => s.toJson()).toList(),
    };
  }
}

/// Model representing a doctor's complete schedule
class DoctorSchedule {
  final String doctorId;
  final Map<String, DaySchedule> weeklySchedule;
  final DateTime? updatedAt;

  DoctorSchedule({
    required this.doctorId,
    required this.weeklySchedule,
    this.updatedAt,
  });

  factory DoctorSchedule.fromJson(Map<String, dynamic> json, String doctorId) {
    final weeklyMap = <String, DaySchedule>{};
    
    // Handle different possible data structures from Firebase
    final schedule = json['schedule'] ?? json['weeklySchedule'] ?? json['weekly_schedule'] ?? json;
    
    if (schedule is Map) {
      schedule.forEach((key, value) {
        if (key != 'doctorId' && key != 'updatedAt' && key != 'updated_at') {
          if (value is Map<String, dynamic>) {
            weeklyMap[key.toString().toLowerCase()] = DaySchedule.fromJson({
              'dayOfWeek': key.toString(),
              ...value,
            });
          } else if (value is List) {
            // If value is a list of time slots
            weeklyMap[key.toString().toLowerCase()] = DaySchedule(
              dayOfWeek: key.toString(),
              isWorkingDay: true,
              timeSlots: (value)
                  .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
                  .toList(),
            );
          }
        }
      });
    }

    DateTime? updated;
    final updatedValue = json['updatedAt'] ?? json['updated_at'];
    if (updatedValue is Timestamp) {
      updated = updatedValue.toDate();
    } else if (updatedValue is String) {
      updated = DateTime.tryParse(updatedValue);
    }

    return DoctorSchedule(
      doctorId: json['doctorId'] ?? json['doctor_id'] ?? doctorId,
      weeklySchedule: weeklyMap,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'doctorId': doctorId,
    };
    weeklySchedule.forEach((key, value) {
      map[key] = value.toJson();
    });
    if (updatedAt != null) {
      map['updatedAt'] = updatedAt;
    }
    return map;
  }

  /// Get schedule for a specific day
  DaySchedule? getScheduleForDay(String dayOfWeek) {
    return weeklySchedule[dayOfWeek.toLowerCase()];
  }

  /// Get available time slots for a specific day
  List<TimeSlot> getAvailableSlotsForDay(String dayOfWeek) {
    final daySchedule = getScheduleForDay(dayOfWeek);
    if (daySchedule == null || !daySchedule.isWorkingDay) {
      return [];
    }
    return daySchedule.timeSlots.where((slot) => slot.isAvailable).toList();
  }

  /// Check if doctor is working on a specific day
  bool isWorkingOnDay(String dayOfWeek) {
    final daySchedule = getScheduleForDay(dayOfWeek);
    return daySchedule?.isWorkingDay ?? false;
  }
}
