import 'package:cloud_firestore/cloud_firestore.dart';

// Export DoctorSchedule and TimeSlot from the dedicated model file
export 'doctor_schedule_model.dart' show DoctorSchedule, TimeSlot;

/// Trạng thái cuộc hẹn
enum AppointmentStatus {
  pending('pending', 'Chờ xác nhận'),
  confirmed('confirmed', 'Đã xác nhận'),
  completed('completed', 'Đã hoàn thành'),
  cancelled('cancelled', 'Đã hủy'),
  rejected('rejected', 'Từ chối');

  const AppointmentStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static AppointmentStatus fromString(String? value) {
    switch (value) {
      case 'pending':
        return AppointmentStatus.pending;
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'rejected':
        return AppointmentStatus.rejected;
      default:
        return AppointmentStatus.pending;
    }
  }
}

/// Model cho cuộc hẹn khám
class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime appointmentDate; // Ngày giờ hẹn khám
  final String reason; // Lý do khám
  final String? notes; // Ghi chú thêm từ bệnh nhân
  final AppointmentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt; // Thời điểm hoàn thành khám
  final String? doctorNotes; // Ghi chú của bác sĩ sau khi khám
  final String? cancelReason; // Lý do hủy (nếu có)
  final bool followUpRequested; // Bệnh nhân yêu cầu theo dõi
  final bool followUpAccepted; // Bác sĩ chấp nhận theo dõi

  const Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.appointmentDate,
    required this.reason,
    this.notes,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.doctorNotes,
    this.cancelReason,
    this.followUpRequested = false,
    this.followUpAccepted = false,
  });

  factory Appointment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Appointment(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      doctorId: data['doctorId'] as String? ?? '',
      appointmentDate: _parseTimestamp(data['appointmentDate']),
      reason: data['reason'] as String? ?? '',
      notes: data['notes'] as String?,
      status: AppointmentStatus.fromString(data['status'] as String?),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: data['updatedAt'] != null
          ? _parseTimestamp(data['updatedAt'])
          : null,
      completedAt: data['completedAt'] != null
          ? _parseTimestamp(data['completedAt'])
          : null,
      doctorNotes: data['doctorNotes'] as String?,
      cancelReason: data['cancelReason'] as String?,
      followUpRequested: data['followUpRequested'] as bool? ?? false,
      followUpAccepted: data['followUpAccepted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'patientId': patientId,
    'doctorId': doctorId,
    'appointmentDate': Timestamp.fromDate(appointmentDate),
    'reason': reason,
    if (notes != null) 'notes': notes,
    'status': status.value,
    'createdAt': Timestamp.fromDate(createdAt),
    if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    if (doctorNotes != null) 'doctorNotes': doctorNotes,
    if (cancelReason != null) 'cancelReason': cancelReason,
    'followUpRequested': followUpRequested,
    'followUpAccepted': followUpAccepted,
  };

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  Appointment copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    DateTime? appointmentDate,
    String? reason,
    String? notes,
    AppointmentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? doctorNotes,
    String? cancelReason,
    bool? followUpRequested,
    bool? followUpAccepted,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      cancelReason: cancelReason ?? this.cancelReason,
      followUpRequested: followUpRequested ?? this.followUpRequested,
      followUpAccepted: followUpAccepted ?? this.followUpAccepted,
    );
  }
}
