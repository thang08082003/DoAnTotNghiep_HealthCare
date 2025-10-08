import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import '../data/models/doctor_model.dart';
import '../data/repositories/user_repository.dart';
import 'user_provider.dart';

// Provider
final doctorSpecialtySelectionProvider =
    StateNotifierProvider<
      DoctorSpecialtySelectionNotifier,
      DoctorSpecialtySelectionState
    >((ref) {
      final userRepository = ref.watch(userRepositoryProvider);
      return DoctorSpecialtySelectionNotifier(userRepository);
    });

// State
class DoctorSpecialtySelectionState {
  final bool isLoading;
  final Specialty? selectedSpecialty;
  final String? errorMessage;

  const DoctorSpecialtySelectionState({
    this.isLoading = false,
    this.selectedSpecialty,
    this.errorMessage,
  });

  DoctorSpecialtySelectionState copyWith({
    bool? isLoading,
    Specialty? selectedSpecialty,
    String? errorMessage,
  }) {
    return DoctorSpecialtySelectionState(
      isLoading: isLoading ?? this.isLoading,
      selectedSpecialty: selectedSpecialty ?? this.selectedSpecialty,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get canProceed => selectedSpecialty != null;
}

// Result model
class DoctorSelectionResult {
  final bool success;
  final String? message;

  const DoctorSelectionResult({required this.success, this.message});
}

// Notifier
class DoctorSpecialtySelectionNotifier
    extends StateNotifier<DoctorSpecialtySelectionState> {
  final UserRepository _userRepository;

  DoctorSpecialtySelectionNotifier(this._userRepository)
    : super(const DoctorSpecialtySelectionState());

  void resetSelection() {
    state = const DoctorSpecialtySelectionState();
  }

  void selectSpecialty(Specialty specialty) {
    state = state.copyWith(selectedSpecialty: specialty);
  }

  Future<DoctorSelectionResult> completeDoctorSetup({
    required String doctorId,
    required String doctorName,
    required String doctorEmail,
    int? yearsExperience,
    String? phone,
    String? description,
    String? gender,
  }) async {
    if (state.selectedSpecialty == null) {
      return const DoctorSelectionResult(
        success: false,
        message: 'Vui lòng chọn chuyên khoa',
      );
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Create doctor user in database
      await _userRepository.createUser(
        uid: doctorId,
        name: doctorName,
        email: doctorEmail,
        role: UserRole.doctor,
        specialty: state.selectedSpecialty!.englishName,
        yearsExperience: yearsExperience,
        phone: phone,
        description: description,
        gender: gender,
        // Set a diseaseFocus mirror so các chỗ dùng diseaseFocus không bị null nếu logic cũ còn tham chiếu
        // (ví dụ mapping dashboard cũ). Có thể bỏ nếu chắc không cần.
        diseaseFocus: state.selectedSpecialty!.toDiseaseFocus().value,
      );

      state = state.copyWith(isLoading: false);

      return DoctorSelectionResult(
        success: true,
        message: 'Đăng ký thành công! Chào mừng BS. $doctorName.',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());

      return DoctorSelectionResult(
        success: false,
        message: 'Lỗi khi đăng ký: $e',
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
