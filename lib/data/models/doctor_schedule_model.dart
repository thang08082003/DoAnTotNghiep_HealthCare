import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho lịch làm việc của bác sĩ
/// Bác sĩ có thể set lịch theo ngày, chỉ định khung giờ làm việc
class DoctorSchedule {
  final String id;
  final String doctorId;
  final DateTime date; // Ngày làm việc
  final List<TimeSlot> timeSlots; // Danh sách khung giờ
  final bool isAvailable; // Có sẵn sàng nhận lịch không
  final String? note; // Ghi chú (VD: nghỉ, hội nghị...)
  final DateTime createdAt;
  final DateTime updatedAt;

  DoctorSchedule({
    required this.id,
    required this.doctorId,
    required this.date,
    required this.timeSlots,
    this.isAvailable = true,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  // Tạo schedule từ Firestore DocumentSnapshot
  factory DoctorSchedule.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return DoctorSchedule(
      id: doc.id,
      doctorId: data['doctorId'] as String,
      date: (data['date'] as Timestamp).toDate(),
      timeSlots: (data['timeSlots'] as List<dynamic>)
          .map((slot) => TimeSlot.fromJson(slot as Map<String, dynamic>))
          .toList(),
      isAvailable: data['isAvailable'] as bool? ?? true,
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Tạo schedule từ JSON (compatibility)
  factory DoctorSchedule.fromJson(Map<String, dynamic> json, String id) {
    return DoctorSchedule(
      id: id,
      doctorId: json['doctorId'] as String,
      date: (json['date'] as Timestamp).toDate(),
      timeSlots: (json['timeSlots'] as List<dynamic>)
          .map((slot) => TimeSlot.fromJson(slot as Map<String, dynamic>))
          .toList(),
      isAvailable: json['isAvailable'] as bool? ?? true,
      note: json['note'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convert schedule sang Firestore
  Map<String, dynamic> toJson() {
    return {
      'doctorId': doctorId,
      'date': Timestamp.fromDate(date),
      'timeSlots': timeSlots.map((slot) => slot.toJson()).toList(),
      'isAvailable': isAvailable,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Alias for compatibility with Firestore operations
  Map<String, dynamic> toMap() => toJson();

  // Getter for notes (compatibility with old model)
  String? get notes => note;

  // Copy with method
  DoctorSchedule copyWith({
    String? id,
    String? doctorId,
    DateTime? date,
    List<TimeSlot>? timeSlots,
    bool? isAvailable,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorSchedule(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      date: date ?? this.date,
      timeSlots: timeSlots ?? this.timeSlots,
      isAvailable: isAvailable ?? this.isAvailable,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model cho khung giờ làm việc
class TimeSlot {
  final String startTime; // "08:00"
  final String endTime; // "09:00"
  final bool isBooked; // Đã có người đặt chưa
  final String? appointmentId; // ID của appointment nếu đã đặt

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.appointmentId,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      isBooked: json['isBooked'] as bool? ?? false,
      appointmentId: json['appointmentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'isBooked': isBooked,
      'appointmentId': appointmentId,
    };
  }

  // Alias for compatibility
  Map<String, dynamic> toMap() => toJson();

  // Factory from Map for compatibility
  factory TimeSlot.fromMap(Map<String, dynamic> map) => TimeSlot.fromJson(map);

  TimeSlot copyWith({
    String? startTime,
    String? endTime,
    bool? isBooked,
    String? appointmentId,
  }) {
    return TimeSlot(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isBooked: isBooked ?? this.isBooked,
      appointmentId: appointmentId ?? this.appointmentId,
    );
  }

  // Kiểm tra slot có available không
  bool get isAvailable => !isBooked;

  // Format để hiển thị: "08:00 - 09:00"
  String get displayTime => '$startTime - $endTime';
}

/// Predefined time slots (các khung giờ mặc định)
class DefaultTimeSlots {
  // Buổi sáng: 8:00 - 12:00
  static List<TimeSlot> morningSlots = [
    TimeSlot(startTime: '08:00', endTime: '08:30'),
    TimeSlot(startTime: '08:30', endTime: '09:00'),
    TimeSlot(startTime: '09:00', endTime: '09:30'),
    TimeSlot(startTime: '09:30', endTime: '10:00'),
    TimeSlot(startTime: '10:00', endTime: '10:30'),
    TimeSlot(startTime: '10:30', endTime: '11:00'),
    TimeSlot(startTime: '11:00', endTime: '11:30'),
    TimeSlot(startTime: '11:30', endTime: '12:00'),
  ];

  // Buổi chiều: 13:00 - 17:00
  static List<TimeSlot> afternoonSlots = [
    TimeSlot(startTime: '13:00', endTime: '13:30'),
    TimeSlot(startTime: '13:30', endTime: '14:00'),
    TimeSlot(startTime: '14:00', endTime: '14:30'),
    TimeSlot(startTime: '14:30', endTime: '15:00'),
    TimeSlot(startTime: '15:00', endTime: '15:30'),
    TimeSlot(startTime: '15:30', endTime: '16:00'),
    TimeSlot(startTime: '16:00', endTime: '16:30'),
    TimeSlot(startTime: '16:30', endTime: '17:00'),
  ];

  // Cả ngày
  static List<TimeSlot> fullDaySlots = [
    ...morningSlots,
    ...afternoonSlots,
  ];
}
