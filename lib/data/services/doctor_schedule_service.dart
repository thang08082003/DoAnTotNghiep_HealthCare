import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_schedule_model.dart';

class DoctorScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'doctor_schedules';

  /// Tạo lịch làm việc mới
  Future<String> createSchedule(DoctorSchedule schedule) async {
    try {
      final docRef = await _firestore
          .collection(_collection)
          .add(schedule.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Lỗi khi tạo lịch làm việc: $e');
    }
  }

  /// Tạo mới hoặc thay thế lịch làm việc theo ngày (upsert theo doctorId + date)
  /// Nếu đã có lịch trong ngày, sẽ cập nhật thay thế toàn bộ timeSlots.
  Future<String> upsertScheduleForDate({
    required String doctorId,
    required DateTime date,
    required List<TimeSlot> timeSlots,
    bool isAvailable = true,
    String? note,
    bool mergeSlots = true,
  }) async {
    try {
      final existing = await getDoctorScheduleByDate(doctorId, date);
      final now = DateTime.now();
      if (existing != null) {
        // Merge or replace time slots
        List<TimeSlot> newSlots;
        if (mergeSlots) {
          // Keep existing slots, add non-overlapping and non-duplicate new slots
          final existingSlots = List<TimeSlot>.from(existing.timeSlots);
          for (final slot in timeSlots) {
            final aStart = _toMinutes(slot.startTime);
            final aEnd = _toMinutes(slot.endTime);
            final hasOverlapOrDuplicate = existingSlots.any((s) {
              final bStart = _toMinutes(s.startTime);
              final bEnd = _toMinutes(s.endTime);
              final duplicate = s.startTime == slot.startTime && s.endTime == slot.endTime;
              return duplicate || (aStart < bEnd && bStart < aEnd);
            });
            if (!hasOverlapOrDuplicate) {
              existingSlots.add(slot);
            }
          }
          existingSlots.sort((a, b) => _toMinutes(a.startTime) - _toMinutes(b.startTime));
          newSlots = existingSlots;
        } else {
          newSlots = timeSlots;
        }

        final updated = existing.copyWith(
          timeSlots: newSlots,
          isAvailable: isAvailable,
          note: note,
          updatedAt: now,
        );
        await updateSchedule(existing.id, updated);
        return existing.id;
      } else {
        final schedule = DoctorSchedule(
          id: '',
          doctorId: doctorId,
          date: date,
          timeSlots: timeSlots,
          isAvailable: isAvailable,
          note: note,
          createdAt: now,
          updatedAt: now,
        );
        return await createSchedule(schedule);
      }
    } catch (e) {
      throw Exception('Lỗi upsert lịch làm việc: $e');
    }
  }

  /// Cập nhật lịch làm việc
  Future<void> updateSchedule(
    String scheduleId,
    DoctorSchedule schedule,
  ) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(scheduleId)
          .update(schedule.copyWith(updatedAt: DateTime.now()).toJson());
    } catch (e) {
      throw Exception('Lỗi khi cập nhật lịch làm việc: $e');
    }
  }

  /// Xóa lịch làm việc
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      await _firestore.collection(_collection).doc(scheduleId).delete();
    } catch (e) {
      throw Exception('Lỗi khi xóa lịch làm việc: $e');
    }
  }

  /// Lấy lịch làm việc theo ID
  Future<DoctorSchedule?> getScheduleById(String scheduleId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(scheduleId)
          .get();
      if (!doc.exists) return null;
      return DoctorSchedule.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Lỗi khi lấy lịch làm việc: $e');
    }
  }

  /// Lấy tất cả lịch làm việc của bác sĩ
  Stream<List<DoctorSchedule>> getDoctorSchedules(String doctorId) {
    return _firestore
        .collection(_collection)
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('date', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DoctorSchedule.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Lấy lịch làm việc của bác sĩ theo khoảng thời gian
  Stream<List<DoctorSchedule>> getDoctorSchedulesByDateRange(
    String doctorId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _firestore
        .collection(_collection)
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DoctorSchedule.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Lấy lịch làm việc của bác sĩ theo ngày cụ thể
  Future<DoctorSchedule?> getDoctorScheduleByDate(
    String doctorId,
    DateTime date,
  ) async {
    try {
      // Normalize date to start of day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection(_collection)
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return DoctorSchedule.fromJson(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    } catch (e) {
      throw Exception('Lỗi khi lấy lịch làm việc theo ngày: $e');
    }
  }

  /// Đánh dấu time slot là đã đặt
  Future<void> markTimeSlotAsBooked(
    String scheduleId,
    String startTime,
    String appointmentId,
  ) async {
    try {
      final schedule = await getScheduleById(scheduleId);
      if (schedule == null) {
        throw Exception('Không tìm thấy lịch làm việc');
      }

      final updatedSlots = schedule.timeSlots.map((slot) {
        if (slot.startTime == startTime) {
          return slot.copyWith(isBooked: true, appointmentId: appointmentId);
        }
        return slot;
      }).toList();

      await updateSchedule(
        scheduleId,
        schedule.copyWith(timeSlots: updatedSlots),
      );
    } catch (e) {
      throw Exception('Lỗi khi đánh dấu time slot: $e');
    }
  }

  /// Hủy đặt time slot
  Future<void> markTimeSlotAsAvailable(
    String scheduleId,
    String startTime,
  ) async {
    try {
      final schedule = await getScheduleById(scheduleId);
      if (schedule == null) {
        throw Exception('Không tìm thấy lịch làm việc');
      }

      final updatedSlots = schedule.timeSlots.map((slot) {
        if (slot.startTime == startTime) {
          return slot.copyWith(isBooked: false, appointmentId: null);
        }
        return slot;
      }).toList();

      await updateSchedule(
        scheduleId,
        schedule.copyWith(timeSlots: updatedSlots),
      );
    } catch (e) {
      throw Exception('Lỗi khi hủy time slot: $e');
    }
  }

  /// Kiểm tra bác sĩ có lịch làm việc trong ngày không
  Future<bool> hasScheduleOnDate(String doctorId, DateTime date) async {
    final schedule = await getDoctorScheduleByDate(doctorId, date);
    return schedule != null && schedule.isAvailable;
  }

  /// Lấy các time slot available trong ngày
  Future<List<TimeSlot>> getAvailableTimeSlots(
    String doctorId,
    DateTime date,
  ) async {
    final schedule = await getDoctorScheduleByDate(doctorId, date);
    if (schedule == null || !schedule.isAvailable) {
      return [];
    }

    return schedule.timeSlots.where((slot) => slot.isAvailable).toList();
  }

  /// Tạo lịch làm việc hàng loạt (VD: cả tuần)
  Future<void> createBulkSchedules(List<DoctorSchedule> schedules) async {
    try {
      // Upsert by doctorId + date to avoid duplicates
      for (var schedule in schedules) {
        await upsertScheduleForDate(
          doctorId: schedule.doctorId,
          date: schedule.date,
          timeSlots: schedule.timeSlots,
          isAvailable: schedule.isAvailable,
          note: schedule.note,
        );
      }
    } catch (e) {
      throw Exception('Lỗi khi tạo lịch làm việc hàng loạt: $e');
    }
  }

  /// Xóa tất cả lịch làm việc của bác sĩ trong khoảng thời gian
  Future<void> deleteSchedulesByDateRange(
    String doctorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Lỗi khi xóa lịch làm việc hàng loạt: $e');
    }
  }

  /// Cập nhật một time slot (đổi giờ bắt đầu/kết thúc). Không cho phép nếu slot đã được đặt.
  Future<void> updateTimeSlot(
    String scheduleId,
    String originalStartTime,
    TimeSlot updatedSlot,
  ) async {
    try {
      final schedule = await getScheduleById(scheduleId);
      if (schedule == null) {
        throw Exception('Không tìm thấy lịch làm việc');
      }

      // Chặn sửa nếu slot hiện tại đang booked
      final current = schedule.timeSlots.firstWhere(
        (s) => s.startTime == originalStartTime,
        orElse: () => throw Exception('Không tìm thấy khung giờ cần sửa'),
      );
      if (current.isBooked) {
        throw Exception('Không thể sửa khung giờ đã có lịch hẹn');
      }

      // Không cho trùng/đè với slot khác
      bool overlap = schedule.timeSlots.any((s) {
        if (s.startTime == originalStartTime) return false; // bỏ qua chính nó
        final aStart = _toMinutes(updatedSlot.startTime);
        final aEnd = _toMinutes(updatedSlot.endTime);
        final bStart = _toMinutes(s.startTime);
        final bEnd = _toMinutes(s.endTime);
        return aStart < bEnd && bStart < aEnd; // overlap tiêu chuẩn
      });
      if (overlap) {
        throw Exception('Khung giờ trùng với khung giờ khác');
      }

      final updated =
          schedule.timeSlots.map((s) {
            if (s.startTime == originalStartTime) {
              return updatedSlot.copyWith(isBooked: false, appointmentId: null);
            }
            return s;
          }).toList()..sort(
            (a, b) => _toMinutes(a.startTime) - _toMinutes(b.startTime),
          );

      await updateSchedule(
        scheduleId,
        schedule.copyWith(timeSlots: updated, updatedAt: DateTime.now()),
      );
    } catch (e) {
      throw Exception('Lỗi khi cập nhật khung giờ: $e');
    }
  }

  /// Xóa một time slot. Không cho phép nếu đã được đặt.
  Future<void> deleteTimeSlot(String scheduleId, String startTime) async {
    try {
      final schedule = await getScheduleById(scheduleId);
      if (schedule == null) {
        throw Exception('Không tìm thấy lịch làm việc');
      }

      final target = schedule.timeSlots.firstWhere(
        (s) => s.startTime == startTime,
        orElse: () => throw Exception('Không tìm thấy khung giờ cần xóa'),
      );
      if (target.isBooked) {
        throw Exception('Không thể xóa khung giờ đã có lịch hẹn');
      }

      final updated = schedule.timeSlots
          .where((s) => s.startTime != startTime)
          .toList();

      await updateSchedule(
        scheduleId,
        schedule.copyWith(timeSlots: updated, updatedAt: DateTime.now()),
      );
    } catch (e) {
      throw Exception('Lỗi khi xóa khung giờ: $e');
    }
  }

  // Helpers
  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }
}
