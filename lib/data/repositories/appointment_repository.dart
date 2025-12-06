import '../services/appointment_service.dart';
import '../models/appointment_model.dart';

/// Repository layer - facade pattern cho appointment service
/// Giúp tách biệt business logic và data access
class AppointmentRepository {
  final AppointmentService _service;

  AppointmentRepository({AppointmentService? service})
    : _service = service ?? AppointmentService();

  // === PATIENT ACTIONS ===

  /// Đặt lịch khám mới
  Future<String> bookAppointment({
    required String patientId,
    required String doctorId,
    required DateTime appointmentDate,
    required String reason,
    String? notes,
  }) {
    return _service.createAppointment(
      patientId: patientId,
      doctorId: doctorId,
      appointmentDate: appointmentDate,
      reason: reason,
      notes: notes,
    );
  }

  /// Yêu cầu theo dõi sau khi khám
  Future<void> requestFollowUp(String appointmentId, String patientId) {
    return _service.requestFollowUp(appointmentId, patientId);
  }

  /// Lấy danh sách cuộc hẹn của bệnh nhân
  Stream<List<Appointment>> watchPatientAppointments(String patientId) {
    return _service.getPatientAppointments(patientId);
  }

  /// Hủy cuộc hẹn
  Future<void> cancelAppointment(
    String appointmentId,
    String userId, {
    String? reason,
  }) {
    return _service.cancelAppointment(appointmentId, userId, reason: reason);
  }

  // === DOCTOR ACTIONS ===

  /// Xác nhận cuộc hẹn
  Future<void> confirmAppointment(String appointmentId, String doctorId) {
    return _service.confirmAppointment(appointmentId, doctorId);
  }

  /// Từ chối cuộc hẹn
  Future<void> rejectAppointment(
    String appointmentId,
    String doctorId, {
    String? reason,
  }) {
    return _service.rejectAppointment(appointmentId, doctorId, reason: reason);
  }

  /// Hoàn thành cuộc khám
  Future<void> completeAppointment(
    String appointmentId,
    String doctorId, {
    String? doctorNotes,
  }) {
    return _service.completeAppointment(
      appointmentId,
      doctorId,
      doctorNotes: doctorNotes,
    );
  }

  /// Chấp nhận theo dõi bệnh nhân
  Future<void> acceptFollowUp(String appointmentId, String doctorId) {
    return _service.acceptFollowUp(appointmentId, doctorId);
  }

  /// Từ chối theo dõi bệnh nhân (sau khám)
  Future<void> declineFollowUp(String appointmentId, String doctorId) {
    return _service.declineFollowUp(appointmentId, doctorId);
  }

  /// Lấy danh sách cuộc hẹn của bác sĩ
  Stream<List<Appointment>> watchDoctorAppointments(String doctorId) {
    return _service.getDoctorAppointments(doctorId);
  }

  /// Thiết lập lịch làm việc
  Future<void> setSchedule({
    required String doctorId,
    required DateTime date,
    required List<TimeSlot> timeSlots,
    bool isAvailable = true,
    String? notes,
  }) {
    return _service.setDoctorSchedule(
      doctorId: doctorId,
      date: date,
      timeSlots: timeSlots,
      isAvailable: isAvailable,
      notes: notes,
    );
  }

  // === COMMON ===

  /// Lấy chi tiết cuộc hẹn
  Future<Appointment?> getAppointmentById(String appointmentId) {
    return _service.getAppointmentById(appointmentId);
  }

  /// Lấy lịch làm việc của bác sĩ
  Future<DoctorSchedule?> getDoctorSchedule(String doctorId, DateTime date) {
    return _service.getDoctorSchedule(doctorId, date);
  }

  /// Lấy các ngày có lịch của bác sĩ (trong tháng)
  Future<List<DateTime>> getDoctorAvailableDates(
    String doctorId,
    DateTime month,
  ) async {
    // Implement nếu cần - query schedules trong tháng
    // Hiện tại return empty list
    return [];
  }
}
