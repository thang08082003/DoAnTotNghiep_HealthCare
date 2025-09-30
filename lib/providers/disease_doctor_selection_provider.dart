import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import '../data/models/doctor_model.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/patient_doctor_assignment_service.dart';
import 'user_provider.dart';

// Provider
final diseaseDoctorSelectionProvider = StateNotifierProvider<DiseaseDoctorSelectionNotifier, DiseaseDoctorSelectionState>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return DiseaseDoctorSelectionNotifier(userRepository);
});

// State
class DiseaseDoctorSelectionState {
  final bool isLoading;
  final bool isLoadingDoctors;
  final DiseaseFocus? selectedDiseaseFocus;
  final DoctorModel? selectedDoctor;
  final List<DoctorModel> availableDoctors;
  final String? errorMessage;

  const DiseaseDoctorSelectionState({
    this.isLoading = false,
    this.isLoadingDoctors = false,
    this.selectedDiseaseFocus,
    this.selectedDoctor,
    this.availableDoctors = const [],
    this.errorMessage,
  });

  DiseaseDoctorSelectionState copyWith({
    bool? isLoading,
    bool? isLoadingDoctors,
    DiseaseFocus? selectedDiseaseFocus,
    DoctorModel? selectedDoctor,
    List<DoctorModel>? availableDoctors,
    String? errorMessage,
  }) {
    return DiseaseDoctorSelectionState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingDoctors: isLoadingDoctors ?? this.isLoadingDoctors,
      selectedDiseaseFocus: selectedDiseaseFocus ?? this.selectedDiseaseFocus,
      selectedDoctor: selectedDoctor ?? this.selectedDoctor,
      availableDoctors: availableDoctors ?? this.availableDoctors,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get canProceed => selectedDiseaseFocus != null;
}

// Result model
class SelectionResult {
  final bool success;
  final String? message;

  const SelectionResult({
    required this.success,
    this.message,
  });
}

// Notifier
class DiseaseDoctorSelectionNotifier extends StateNotifier<DiseaseDoctorSelectionState> {
  final UserRepository _userRepository;
  final PatientDoctorAssignmentService _assignmentService = PatientDoctorAssignmentService();

  DiseaseDoctorSelectionNotifier(this._userRepository) : super(const DiseaseDoctorSelectionState());

  void resetSelection() {
    state = const DiseaseDoctorSelectionState();
  }

  Future<void> selectDiseaseFocus(DiseaseFocus diseaseFocus) async {
    state = state.copyWith(
      selectedDiseaseFocus: diseaseFocus,
      selectedDoctor: null, // Reset doctor selection
      isLoadingDoctors: true,
    );

    try {
      // Load doctors for this disease focus
      final allUsers = await _userRepository.getUsersByRole(UserRole.doctor);
      
      final doctorModels = <DoctorModel>[];
      
      for (final user in allUsers) {
        // Check if user data contains specialty field (indicating it's a DoctorModel)
        if (user.role == UserRole.doctor) {
          // Try to create DoctorModel from user data
          try {
            final doctor = DoctorModel.fromUserModel(user);
            
            // Check if specialty matches the disease focus
            if (doctor.specialty == diseaseFocus.toSpecialty()) {
              doctorModels.add(doctor);
            }
          } catch (e) {
            // Skip users that can't be converted to DoctorModel - this is expected for some cases
            continue;
          }
        }
      }
      
      state = state.copyWith(
        availableDoctors: doctorModels,
        isLoadingDoctors: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingDoctors: false,
        errorMessage: 'Lỗi khi tải danh sách bác sĩ: $e',
      );
    }
  }

  void selectDoctor(DoctorModel doctor) {
    state = state.copyWith(selectedDoctor: doctor);
  }

  Future<SelectionResult> completePatientSetup({
    required String patientId,
    required String patientName,
    required String patientEmail,
  }) async {
    if (state.selectedDiseaseFocus == null) {
      return const SelectionResult(
        success: false,
        message: 'Vui lòng chọn loại bệnh',
      );
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Create user in database
      await _userRepository.createUser(
        uid: patientId,
        name: patientName,
        email: patientEmail,
        role: UserRole.patient,
        diseaseFocus: state.selectedDiseaseFocus!.value,
      );

      String? assignedDoctorId;
      
      if (state.selectedDoctor != null) {
        // User selected a specific doctor
        assignedDoctorId = state.selectedDoctor!.uid;
        
        // Update patient with assigned doctor
        final patient = await _userRepository.getUserById(patientId);
        if (patient != null) {
          final updatedPatient = patient.copyWith(
            assignedDoctorId: assignedDoctorId,
          );
          await _userRepository.updateUser(updatedPatient);
        }
      } else {
        // Auto-assign doctor using load balancing
        assignedDoctorId = await _assignmentService.assignDoctorToPatient(
          patientId: patientId,
          diseaseFocus: state.selectedDiseaseFocus!,
        );
      }

      state = state.copyWith(isLoading: false);

      if (assignedDoctorId != null) {
        final doctorName = state.selectedDoctor?.name ?? 'một bác sĩ chuyên khoa';
        return SelectionResult(
          success: true,
          message: 'Đăng ký thành công! Đã gán $doctorName cho bạn.',
        );
      } else {
        return const SelectionResult(
          success: true,
          message: 'Đăng ký thành công! Hiện chưa có bác sĩ chuyên khoa phù hợp.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      
      return SelectionResult(
        success: false,
        message: 'Lỗi khi đăng ký: $e',
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}