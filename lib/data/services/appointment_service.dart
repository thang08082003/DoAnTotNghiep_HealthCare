import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

/// Service xử lý logic nghiệp vụ cho appointments
class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');
  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection('doctor_schedules');

  /// Tạo cuộc hẹn mới (từ bệnh nhân)
  Future<String> createAppointment({
    required String patientId,
    required String doctorId,
    required DateTime appointmentDate,
    required String reason,
    String? notes,
  }) async {
    final now = DateTime.now();

    // Kiểm tra slot còn trống không
    final isAvailable = await _checkSlotAvailability(doctorId, appointmentDate);
    if (!isAvailable) {
      throw Exception('Khung giờ này đã được đặt. Vui lòng chọn giờ khác.');
    }

    final appointment = Appointment(
      id: '',
      patientId: patientId,
      doctorId: doctorId,
      appointmentDate: appointmentDate,
      reason: reason,
      notes: notes,
      status: AppointmentStatus.pending,
      createdAt: now,
    );

    final docRef = await _appointments.add(appointment.toMap());

    // Gửi notification cho bác sĩ
    await NotificationService.createNotification(
      toUserId: doctorId,
      senderId: patientId,
      type: NotificationType.appointment,
      title: 'Yêu cầu đặt lịch khám mới',
      body:
          'Bạn có một yêu cầu đặt lịch khám mới vào ${_formatDateTime(appointmentDate)}',
      data: {'appointmentId': docRef.id},
    );

    return docRef.id;
  }

  /// Kiểm tra khung giờ còn trống không
  Future<bool> _checkSlotAvailability(
    String doctorId,
    DateTime dateTime,
  ) async {
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final endOfDay = date.add(const Duration(days: 1));
    final timeString = _formatTimeOnly(dateTime);

    final scheduleQuery = await _schedules
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (scheduleQuery.docs.isEmpty) {
      // Chưa có lịch cho ngày này - có thể đặt
      return true;
    }

    final schedule = DoctorSchedule.fromFirestore(scheduleQuery.docs.first);

    // Tìm slot tương ứng
    for (final slot in schedule.timeSlots) {
      if (slot.startTime == timeString && slot.isBooked) {
        return false;
      }
    }

    return true;
  }

  /// Xác nhận cuộc hẹn (bác sĩ)
  Future<void> confirmAppointment(String appointmentId, String doctorId) async {
    final doc = await _appointments.doc(appointmentId).get();
    if (!doc.exists) {
      throw Exception('Không tìm thấy cuộc hẹn');
    }

    final appointment = Appointment.fromFirestore(doc);
    if (appointment.doctorId != doctorId) {
      throw Exception('Bạn không có quyền xác nhận cuộc hẹn này');
    }

    await _appointments.doc(appointmentId).update({
      'status': AppointmentStatus.confirmed.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update schedule slot
    await _updateScheduleSlot(
      appointment.doctorId,
      appointment.appointmentDate,
      appointmentId,
      isBooked: true,
    );

    // Gửi notification cho bệnh nhân
    await NotificationService.createNotification(
      toUserId: appointment.patientId,
      senderId: doctorId,
      type: NotificationType.appointment,
      title: 'Lịch khám đã được xác nhận',
      body:
          'Bác sĩ đã xác nhận lịch khám của bạn vào ${_formatDateTime(appointment.appointmentDate)}',
      data: {'appointmentId': appointmentId},
    );
  }

  /// Từ chối cuộc hẹn (bác sĩ)
  Future<void> rejectAppointment(
    String appointmentId,
    String doctorId, {
    String? reason,
  }) async {
    final doc = await _appointments.doc(appointmentId).get();
    if (!doc.exists) {
      throw Exception('Không tìm thấy cuộc hẹn');
    }

    final appointment = Appointment.fromFirestore(doc);
    if (appointment.doctorId != doctorId) {
      throw Exception('Bạn không có quyền từ chối cuộc hẹn này');
    }

    await _appointments.doc(appointmentId).update({
      'status': AppointmentStatus.rejected.value,
      'cancelReason': reason ?? 'Bác sĩ không thể sắp xếp',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Gửi notification cho bệnh nhân
    await NotificationService.createNotification(
      toUserId: appointment.patientId,
      senderId: doctorId,
      type: NotificationType.appointment,
      title: 'Lịch khám bị từ chối',
      body: reason ?? 'Bác sĩ không thể sắp xếp lịch khám này',
      data: {'appointmentId': appointmentId},
    );
  }

  /// Hoàn thành cuộc khám (bác sĩ)
  Future<void> completeAppointment(
    String appointmentId,
    String doctorId, {
    String? doctorNotes,
  }) async {
    final doc = await _appointments.doc(appointmentId).get();
    if (!doc.exists) {
      throw Exception('Không tìm thấy cuộc hẹn');
    }

    final appointment = Appointment.fromFirestore(doc);
    if (appointment.doctorId != doctorId) {
      throw Exception('Bạn không có quyền cập nhật cuộc hẹn này');
    }

    await _appointments.doc(appointmentId).update({
      'status': AppointmentStatus.completed.value,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (doctorNotes != null) 'doctorNotes': doctorNotes,
    });

    // Sau khi hoàn thành khám: giải phóng khung giờ trong lịch làm việc
    await _updateScheduleSlot(
      appointment.doctorId,
      appointment.appointmentDate,
      appointmentId,
      isBooked: false,
    );

    // Gửi notification cho bệnh nhân
    await NotificationService.createNotification(
      toUserId: appointment.patientId,
      senderId: doctorId,
      type: NotificationType.appointment,
      title: 'Đã hoàn thành khám',
      body: 'Cuộc khám đã hoàn thành. Bạn có thể yêu cầu theo dõi từ bác sĩ.',
      data: {'appointmentId': appointmentId},
    );
  }

  /// Yêu cầu theo dõi sau khi khám (bệnh nhân)
  Future<void> requestFollowUp(String appointmentId, String patientId) async {
    final doc = await _appointments.doc(appointmentId).get();
    if (!doc.exists) {
      throw Exception('Không tìm thấy cuộc hẹn');
    }

    final appointment = Appointment.fromFirestore(doc);
    if (appointment.patientId != patientId) {
      throw Exception('Bạn không có quyền yêu cầu theo dõi cuộc hẹn này');
    }

    if (appointment.status != AppointmentStatus.completed) {
      throw Exception('Chỉ có thể yêu cầu theo dõi sau khi hoàn thành khám');
    }

    await _appointments.doc(appointmentId).update({
      'followUpRequested': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Gửi notification cho bác sĩ
    await NotificationService.createNotification(
      toUserId: appointment.doctorId,
      senderId: patientId,
      type: NotificationType.followRequest,
      title: 'Yêu cầu theo dõi sức khỏe',
      body: 'Bệnh nhân yêu cầu theo dõi sức khỏe sau khi khám',
      data: {
        'appointmentId': appointmentId,
        'patientId': appointment.patientId,
        'doctorId': appointment.doctorId,
      },
    );
  }

  /// Chấp nhận theo dõi (bác sĩ)
  Future<void> acceptFollowUp(String appointmentId, String doctorId) async {
    final doc = await _appointments.doc(appointmentId).get();
    if (!doc.exists) {
      throw Exception('Không tìm thấy cuộc hẹn');
    }

    final appointment = Appointment.fromFirestore(doc);
    if (appointment.doctorId != doctorId) {
      throw Exception('Bạn không có quyền chấp nhận yêu cầu này');
    }

    await _appointments.doc(appointmentId).update({
      'followUpAccepted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Tạo patient-doctor assignment (sử dụng lại logic cũ)
    await _createPatientDoctorAssignment(
      patientId: appointment.patientId,
      doctorId: doctorId,
    );

    // Đồng bộ follow_requests: chuyển pending -> accepted (nếu có), hoặc tạo mới accepted nếu chưa tồn tại
    try {
      final frDocId = '${appointment.patientId}_${appointment.doctorId}';
      final frRef = _firestore.collection('follow_requests').doc(frDocId);
      final frSnap = await frRef.get();
      if (frSnap.exists) {
        await frRef.update({
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await frRef.set({
          'patientId': appointment.patientId,
          'doctorId': appointment.doctorId,
          'status': 'accepted',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // no-op
    }

    // Gửi notification cho bệnh nhân
    await NotificationService.createNotification(
      toUserId: appointment.patientId,
      senderId: doctorId,
      type: NotificationType.followRequest,
      title: 'Bác sĩ đã chấp nhận theo dõi',
      body: 'Bác sĩ đã chấp nhận theo dõi sức khỏe của bạn',
      data: {'appointmentId': appointmentId},
    );
  }

  /// Từ chối theo dõi (bác sĩ) cho yêu cầu follow-up sau khám
  Future<void> declineFollowUp(String appointmentId, String doctorId) async {
    final doc = await _appointments.doc(appointmentId).get();
    if (!doc.exists) {
      throw Exception('Không tìm thấy cuộc hẹn');
    }

    final appointment = Appointment.fromFirestore(doc);
    if (appointment.doctorId != doctorId) {
      throw Exception('Bạn không có quyền từ chối yêu cầu này');
    }

    // Đơn giản: bỏ trạng thái followUpRequested về false
    await _appointments.doc(appointmentId).update({
      'followUpRequested': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Đồng bộ follow_requests: nếu đang pending thì chuyển -> rejected
    try {
      final frDocId = '${appointment.patientId}_${appointment.doctorId}';
      final frRef = _firestore.collection('follow_requests').doc(frDocId);
      final frSnap = await frRef.get();
      if (frSnap.exists) {
        await frRef.update({
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // no-op
    }

    // Thông báo cho bệnh nhân
    await NotificationService.createNotification(
      toUserId: appointment.patientId,
      senderId: doctorId,
      type: NotificationType.followRequest,
      title: 'Bác sĩ đã từ chối theo dõi',
      body: 'Yêu cầu theo dõi sau khám của bạn đã bị từ chối',
      data: {'appointmentId': appointmentId},
    );
  }

  /// Hủy cuộc hẹn (bệnh nhân hoặc bác sĩ)
  Future<void> cancelAppointment(
    String appointmentId,
    String userId, {
    String? reason,
  }) async {
    final doc = await _appointments.doc(appointmentId).get();
    if (!doc.exists) {
      throw Exception('Không tìm thấy cuộc hẹn');
    }

    final appointment = Appointment.fromFirestore(doc);
    if (appointment.patientId != userId && appointment.doctorId != userId) {
      throw Exception('Bạn không có quyền hủy cuộc hẹn này');
    }

    // Không cho hủy nếu đã hoàn thành
    if (appointment.status == AppointmentStatus.completed) {
      throw Exception('Không thể hủy cuộc hẹn đã hoàn thành');
    }

    await _appointments.doc(appointmentId).update({
      'status': AppointmentStatus.cancelled.value,
      'cancelReason': reason ?? 'Người dùng hủy',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update schedule slot nếu đã confirmed
    if (appointment.status == AppointmentStatus.confirmed) {
      await _updateScheduleSlot(
        appointment.doctorId,
        appointment.appointmentDate,
        appointmentId,
        isBooked: false,
      );
    }

    // Gửi notification cho người còn lại
    final recipientId = userId == appointment.patientId
        ? appointment.doctorId
        : appointment.patientId;

    await NotificationService.createNotification(
      toUserId: recipientId,
      senderId: userId,
      type: NotificationType.appointment,
      title: 'Lịch khám đã bị hủy',
      body: reason ?? 'Lịch khám đã bị hủy',
      data: {'appointmentId': appointmentId},
    );
  }

  /// Lấy danh sách cuộc hẹn của bệnh nhân
  Stream<List<Appointment>> getPatientAppointments(String patientId) {
    return _appointments
        .where('patientId', isEqualTo: patientId)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Appointment.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy danh sách cuộc hẹn của bác sĩ
  Stream<List<Appointment>> getDoctorAppointments(String doctorId) {
    return _appointments
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Appointment.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy cuộc hẹn theo ID
  Future<Appointment?> getAppointmentById(String appointmentId) async {
    final doc = await _appointments.doc(appointmentId).get();
    if (!doc.exists) return null;
    return Appointment.fromFirestore(doc);
  }

  /// Lấy lịch làm việc của bác sĩ theo ngày
  Future<DoctorSchedule?> getDoctorSchedule(
    String doctorId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    print(
      '🔍 [getDoctorSchedule] Querying for doctorId: $doctorId, date: $startOfDay',
    );

    final query = await _schedules
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    print(
      '📊 [getDoctorSchedule] Query returned ${query.docs.length} documents',
    );

    if (query.docs.isEmpty) {
      print('❌ [getDoctorSchedule] No schedule found');
      return null;
    }

    final schedule = DoctorSchedule.fromFirestore(query.docs.first);
    print(
      '✅ [getDoctorSchedule] Schedule found with ${schedule.timeSlots.length} time slots',
    );
    print('   - isAvailable: ${schedule.isAvailable}');
    print(
      '   - timeSlots: ${schedule.timeSlots.map((s) => s.startTime).join(", ")}',
    );

    return schedule;
  }

  /// Tạo/cập nhật lịch làm việc (bác sĩ)
  Future<void> setDoctorSchedule({
    required String doctorId,
    required DateTime date,
    required List<TimeSlot> timeSlots,
    bool isAvailable = true,
    String? notes,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final now = DateTime.now();

    final existingQuery = await _schedules
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    final schedule = DoctorSchedule(
      id: existingQuery.docs.isNotEmpty ? existingQuery.docs.first.id : '',
      doctorId: doctorId,
      date: startOfDay,
      timeSlots: timeSlots,
      isAvailable: isAvailable,
      note: notes,
      createdAt: existingQuery.docs.isNotEmpty
          ? (existingQuery.docs.first.data()['createdAt'] as Timestamp).toDate()
          : now,
      updatedAt: now,
    );

    if (existingQuery.docs.isEmpty) {
      await _schedules.add(schedule.toMap());
    } else {
      await _schedules
          .doc(existingQuery.docs.first.id)
          .update(schedule.toMap());
    }
  }

  /// Update schedule slot status
  Future<void> _updateScheduleSlot(
    String doctorId,
    DateTime dateTime,
    String appointmentId, {
    required bool isBooked,
  }) async {
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final endOfDay = date.add(const Duration(days: 1));
    final timeString = _formatTimeOnly(dateTime);

    final query = await _schedules
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (query.docs.isEmpty) return;

    final doc = query.docs.first;
    final schedule = DoctorSchedule.fromFirestore(doc);

    final updatedSlots = schedule.timeSlots.map((slot) {
      if (slot.startTime == timeString) {
        return slot.copyWith(
          isBooked: isBooked,
          appointmentId: isBooked ? appointmentId : null,
        );
      }
      return slot;
    }).toList();

    await _schedules.doc(doc.id).update({
      'timeSlots': updatedSlots.map((s) => s.toMap()).toList(),
    });
  }

  /// Tạo patient-doctor assignment (tái sử dụng logic cũ)
  Future<void> _createPatientDoctorAssignment({
    required String patientId,
    required String doctorId,
  }) async {
    // Kiểm tra đã tồn tại chưa
    final existing = await _firestore
        .collection('patient_doctor_assignments')
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Đã tồn tại - không làm gì
      return;
    }

    // Tạo mới
    await _firestore.collection('patient_doctor_assignments').add({
      'patientId': patientId,
      'doctorId': doctorId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Helper methods
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${_formatTimeOnly(dateTime)}';
  }

  String _formatTimeOnly(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
