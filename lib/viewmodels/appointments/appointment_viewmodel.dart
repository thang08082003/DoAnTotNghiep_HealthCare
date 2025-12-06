import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../data/models/doctor_schedule_model.dart';
import '../../data/models/appointment_model.dart';

/// Provider cho AppointmentRepository
final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepository();
});

/// ViewModel cho danh sách appointments của bệnh nhân
/// MVVM Pattern: ViewModel quản lý state và business logic cho UI
class PatientAppointmentsViewModel
    extends AutoDisposeFamilyAsyncNotifier<List<Appointment>, String> {
  @override
  Future<List<Appointment>> build(String patientId) async {
    final repository = ref.read(appointmentRepositoryProvider);

    // Watch stream và convert sang AsyncValue
    final stream = repository.watchPatientAppointments(patientId);

    // Subscribe stream
    final subscription = stream.listen(
      (appointments) {
        state = AsyncData(appointments);
      },
      onError: (error, stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );

    // Cleanup khi dispose
    ref.onDispose(() {
      subscription.cancel();
    });

    // Return initial empty list
    return [];
  }

  /// Đặt lịch khám mới
  Future<void> bookAppointment({
    required String doctorId,
    required DateTime appointmentDate,
    required String reason,
    String? notes,
  }) async {
    final repository = ref.read(appointmentRepositoryProvider);
    final patientId = arg; // arg chứa patientId từ provider family

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.bookAppointment(
        patientId: patientId,
        doctorId: doctorId,
        appointmentDate: appointmentDate,
        reason: reason,
        notes: notes,
      );

      // Return current list
      return state.value ?? [];
    });
  }

  /// Yêu cầu theo dõi sau khi khám
  Future<void> requestFollowUp(String appointmentId) async {
    final repository = ref.read(appointmentRepositoryProvider);
    final patientId = arg;

    state = await AsyncValue.guard(() async {
      await repository.requestFollowUp(appointmentId, patientId);
      return state.value ?? [];
    });
  }

  /// Hủy cuộc hẹn
  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    final repository = ref.read(appointmentRepositoryProvider);
    final patientId = arg;

    state = await AsyncValue.guard(() async {
      await repository.cancelAppointment(
        appointmentId,
        patientId,
        reason: reason,
      );
      return state.value ?? [];
    });
  }

  /// Lọc appointments theo status
  List<Appointment> filterByStatus(AppointmentStatus status) {
    return state.value?.where((apt) => apt.status == status).toList() ?? [];
  }

  /// Lấy upcoming appointments (chưa khám, đã confirm)
  List<Appointment> getUpcomingAppointments() {
    final now = DateTime.now();
    return state.value
            ?.where(
              (apt) =>
                  apt.status == AppointmentStatus.confirmed &&
                  apt.appointmentDate.isAfter(now),
            )
            .toList() ??
        [];
  }

  /// Lấy past appointments (đã hoàn thành hoặc đã qua)
  List<Appointment> getPastAppointments() {
    final now = DateTime.now();
    return state.value
            ?.where(
              (apt) =>
                  apt.status == AppointmentStatus.completed ||
                  (apt.appointmentDate.isBefore(now) &&
                      apt.status != AppointmentStatus.pending),
            )
            .toList() ??
        [];
  }
}

final patientAppointmentsViewModelProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      PatientAppointmentsViewModel,
      List<Appointment>,
      String
    >(PatientAppointmentsViewModel.new);

/// ViewModel cho danh sách appointments của bác sĩ
class DoctorAppointmentsViewModel
    extends AutoDisposeFamilyAsyncNotifier<List<Appointment>, String> {
  @override
  Future<List<Appointment>> build(String doctorId) async {
    final repository = ref.read(appointmentRepositoryProvider);

    final stream = repository.watchDoctorAppointments(doctorId);

    final subscription = stream.listen(
      (appointments) {
        state = AsyncData(appointments);
      },
      onError: (error, stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );

    ref.onDispose(() {
      subscription.cancel();
    });

    return [];
  }

  /// Xác nhận cuộc hẹn
  Future<void> confirmAppointment(String appointmentId) async {
    final repository = ref.read(appointmentRepositoryProvider);
    final doctorId = arg;

    state = await AsyncValue.guard(() async {
      await repository.confirmAppointment(appointmentId, doctorId);
      return state.value ?? [];
    });
  }

  /// Từ chối cuộc hẹn
  Future<void> rejectAppointment(String appointmentId, {String? reason}) async {
    final repository = ref.read(appointmentRepositoryProvider);
    final doctorId = arg;

    state = await AsyncValue.guard(() async {
      await repository.rejectAppointment(
        appointmentId,
        doctorId,
        reason: reason,
      );
      return state.value ?? [];
    });
  }

  /// Hoàn thành cuộc khám
  Future<void> completeAppointment(
    String appointmentId, {
    String? doctorNotes,
  }) async {
    final repository = ref.read(appointmentRepositoryProvider);
    final doctorId = arg;

    state = await AsyncValue.guard(() async {
      await repository.completeAppointment(
        appointmentId,
        doctorId,
        doctorNotes: doctorNotes,
      );
      return state.value ?? [];
    });
  }

  /// Chấp nhận yêu cầu theo dõi
  Future<void> acceptFollowUp(String appointmentId) async {
    final repository = ref.read(appointmentRepositoryProvider);
    final doctorId = arg;

    state = await AsyncValue.guard(() async {
      await repository.acceptFollowUp(appointmentId, doctorId);
      return state.value ?? [];
    });
  }

  /// Từ chối yêu cầu theo dõi (sau khám)
  Future<void> declineFollowUp(String appointmentId) async {
    final repository = ref.read(appointmentRepositoryProvider);
    final doctorId = arg;

    state = await AsyncValue.guard(() async {
      await repository.declineFollowUp(appointmentId, doctorId);
      return state.value ?? [];
    });
  }

  /// Hủy cuộc hẹn
  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    final repository = ref.read(appointmentRepositoryProvider);
    final doctorId = arg;

    state = await AsyncValue.guard(() async {
      await repository.cancelAppointment(
        appointmentId,
        doctorId,
        reason: reason,
      );
      return state.value ?? [];
    });
  }

  /// Lấy pending appointments (chờ xác nhận)
  List<Appointment> getPendingAppointments() {
    return state.value
            ?.where((apt) => apt.status == AppointmentStatus.pending)
            .toList() ??
        [];
  }

  /// Lấy confirmed appointments (đã xác nhận, chưa khám)
  List<Appointment> getConfirmedAppointments() {
    final now = DateTime.now();
    return state.value
            ?.where(
              (apt) =>
                  apt.status == AppointmentStatus.confirmed &&
                  apt.appointmentDate.isAfter(now),
            )
            .toList() ??
        [];
  }

  /// Lấy completed appointments có yêu cầu follow-up chưa chấp nhận
  List<Appointment> getFollowUpRequests() {
    return state.value
            ?.where(
              (apt) =>
                  apt.status == AppointmentStatus.completed &&
                  apt.followUpRequested &&
                  !apt.followUpAccepted,
            )
            .toList() ??
        [];
  }
}

final doctorAppointmentsViewModelProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      DoctorAppointmentsViewModel,
      List<Appointment>,
      String
    >(DoctorAppointmentsViewModel.new);

/// ViewModel cho lịch làm việc của bác sĩ
class DoctorScheduleViewModel
    extends StateNotifier<AsyncValue<DoctorSchedule?>> {
  final Ref ref;
  final String doctorId;
  final DateTime date;

  DoctorScheduleViewModel(this.ref, this.doctorId, this.date)
    : super(const AsyncLoading()) {
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(appointmentRepositoryProvider);
      return await repository.getDoctorSchedule(doctorId, date);
    });
  }

  /// Tạo/cập nhật lịch làm việc
  Future<void> setSchedule({
    required List<TimeSlot> timeSlots,
    bool isAvailable = true,
    String? notes,
  }) async {
    state = await AsyncValue.guard(() async {
      final repository = ref.read(appointmentRepositoryProvider);
      await repository.setSchedule(
        doctorId: doctorId,
        date: date,
        timeSlots: timeSlots,
        isAvailable: isAvailable,
        notes: notes,
      );

      // Reload sau khi set
      return await repository.getDoctorSchedule(doctorId, date);
    });
  }

  /// Refresh lịch
  Future<void> refresh() => _loadSchedule();
}

/// Provider factory cho doctor schedule
final doctorScheduleViewModelProvider = StateNotifierProvider.autoDispose
    .family<
      DoctorScheduleViewModel,
      AsyncValue<DoctorSchedule?>,
      ({String doctorId, DateTime date})
    >((ref, params) {
      return DoctorScheduleViewModel(ref, params.doctorId, params.date);
    });
