import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_schedule_model.dart';

class DoctorScheduleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'doctor_schedules';

  /// Get doctor schedule by doctor ID
  static Future<DoctorSchedule?> getDoctorSchedule(String doctorId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(doctorId).get();
      
      if (doc.exists && doc.data() != null) {
        return DoctorSchedule.fromJson(doc.data()!, doctorId);
      }
      return null;
    } catch (e) {
      throw Exception('Lỗi khi lấy lịch làm việc của bác sĩ: $e');
    }
  }

  /// Stream for real-time schedule updates
  static Stream<DoctorSchedule?> getDoctorScheduleStream(String doctorId) {
    return _firestore
        .collection(_collection)
        .doc(doctorId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return DoctorSchedule.fromJson(doc.data()!, doctorId);
          }
          return null;
        });
  }

  /// Save or update doctor schedule
  static Future<void> saveDoctorSchedule(DoctorSchedule schedule) async {
    try {
      final data = schedule.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore
          .collection(_collection)
          .doc(schedule.doctorId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Lỗi khi lưu lịch làm việc: $e');
    }
  }

  /// Delete doctor schedule
  static Future<void> deleteDoctorSchedule(String doctorId) async {
    try {
      await _firestore.collection(_collection).doc(doctorId).delete();
    } catch (e) {
      throw Exception('Lỗi khi xóa lịch làm việc: $e');
    }
  }

  /// Get available time slots for a doctor on a specific date
  static Future<List<TimeSlot>> getAvailableSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    try {
      final schedule = await getDoctorSchedule(doctorId);
      if (schedule == null) {
        return [];
      }

      // Get day of week from the date
      final dayOfWeek = _getDayOfWeek(date.weekday);
      return schedule.getAvailableSlotsForDay(dayOfWeek);
    } catch (e) {
      throw Exception('Lỗi khi lấy khung giờ trống: $e');
    }
  }

  /// Helper method to convert weekday number to string
  static String _getDayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  /// Get Vietnamese day name
  static String getVietnameseDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }
}
