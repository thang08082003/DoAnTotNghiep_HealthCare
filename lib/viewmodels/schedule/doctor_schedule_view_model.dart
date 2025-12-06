import 'package:flutter/foundation.dart';
import '../../data/models/doctor_schedule_model.dart';
import '../../data/services/doctor_schedule_service.dart';

class DoctorScheduleViewModel extends ChangeNotifier {
  final DoctorScheduleService _scheduleService = DoctorScheduleService();

  bool _isLoading = false;
  String? _error;
  DoctorSchedule? _selectedSchedule;
  List<DoctorSchedule> _schedules = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  DoctorSchedule? get selectedSchedule => _selectedSchedule;
  List<DoctorSchedule> get schedules => _schedules;

  /// Tạo lịch làm việc mới
  Future<bool> createSchedule({
    required String doctorId,
    required DateTime date,
    required List<TimeSlot> timeSlots,
    bool isAvailable = true,
    String? note,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final schedule = DoctorSchedule(
        id: '',
        doctorId: doctorId,
        date: date,
        timeSlots: timeSlots,
        isAvailable: isAvailable,
        note: note,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _scheduleService.createSchedule(schedule);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật lịch làm việc
  Future<bool> updateSchedule(
    String scheduleId,
    DoctorSchedule schedule,
  ) async {
    _setLoading(true);
    _error = null;

    try {
      await _scheduleService.updateSchedule(scheduleId, schedule);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Xóa lịch làm việc
  Future<bool> deleteSchedule(String scheduleId) async {
    _setLoading(true);
    _error = null;

    try {
      await _scheduleService.deleteSchedule(scheduleId);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Lấy lịch làm việc theo ID
  Future<void> fetchScheduleById(String scheduleId) async {
    _setLoading(true);
    _error = null;

    try {
      _selectedSchedule = await _scheduleService.getScheduleById(scheduleId);
      _setLoading(false);
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  /// Lấy lịch làm việc của bác sĩ theo ngày
  Future<DoctorSchedule?> fetchScheduleByDate(
    String doctorId,
    DateTime date,
  ) async {
    _setLoading(true);
    _error = null;

    try {
      final schedule = await _scheduleService.getDoctorScheduleByDate(
        doctorId,
        date,
      );
      _selectedSchedule = schedule;
      _setLoading(false);
      return schedule;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return null;
    }
  }

  /// Lấy các time slot available
  Future<List<TimeSlot>> fetchAvailableTimeSlots(
    String doctorId,
    DateTime date,
  ) async {
    try {
      return await _scheduleService.getAvailableTimeSlots(doctorId, date);
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  /// Tạo lịch làm việc hàng loạt (cả tuần/tháng)
  Future<bool> createBulkSchedules({
    required String doctorId,
    required List<DateTime> dates,
    required List<TimeSlot> timeSlots,
    bool isAvailable = true,
    String? note,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final schedules = dates.map((date) {
        return DoctorSchedule(
          id: '',
          doctorId: doctorId,
          date: date,
          timeSlots: timeSlots
              .map(
                (slot) =>
                    TimeSlot(startTime: slot.startTime, endTime: slot.endTime),
              )
              .toList(),
          isAvailable: isAvailable,
          note: note,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      await _scheduleService.createBulkSchedules(schedules);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Xóa lịch làm việc theo khoảng thời gian
  Future<bool> deleteSchedulesByDateRange(
    String doctorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _setLoading(true);
    _error = null;

    try {
      await _scheduleService.deleteSchedulesByDateRange(
        doctorId,
        startDate,
        endDate,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Subscribe to doctor schedules stream
  Stream<List<DoctorSchedule>> watchDoctorSchedules(String doctorId) {
    return _scheduleService.getDoctorSchedules(doctorId);
  }

  /// Subscribe to schedules by date range
  Stream<List<DoctorSchedule>> watchSchedulesByDateRange(
    String doctorId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _scheduleService.getDoctorSchedulesByDateRange(
      doctorId,
      startDate,
      endDate,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
