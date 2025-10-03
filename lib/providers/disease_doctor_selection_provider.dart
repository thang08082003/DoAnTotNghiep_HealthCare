import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';
import 'user_provider.dart';

// Provider
final diseaseDoctorSelectionProvider =
    StateNotifierProvider<
      DiseaseDoctorSelectionNotifier,
      DiseaseDoctorSelectionState
    >((ref) {
      final userRepository = ref.watch(userRepositoryProvider);
      return DiseaseDoctorSelectionNotifier(userRepository);
    });

// State
class DiseaseDoctorSelectionState {
  final bool isLoading;
  final DiseaseFocus? selectedDiseaseFocus;
  final String? errorMessage;

  const DiseaseDoctorSelectionState({
    this.isLoading = false,
    this.selectedDiseaseFocus,
    this.errorMessage,
  });

  DiseaseDoctorSelectionState copyWith({
    bool? isLoading,
    DiseaseFocus? selectedDiseaseFocus,
    String? errorMessage,
  }) {
    return DiseaseDoctorSelectionState(
      isLoading: isLoading ?? this.isLoading,
      selectedDiseaseFocus: selectedDiseaseFocus ?? this.selectedDiseaseFocus,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get canProceed => selectedDiseaseFocus != null;
}

// Result model
class SelectionResult {
  final bool success;
  final String? message;

  const SelectionResult({required this.success, this.message});
}

// Notifier
class DiseaseDoctorSelectionNotifier
    extends StateNotifier<DiseaseDoctorSelectionState> {
  final UserRepository _userRepository;

  DiseaseDoctorSelectionNotifier(this._userRepository)
    : super(const DiseaseDoctorSelectionState());

  void resetSelection() {
    state = const DiseaseDoctorSelectionState();
  }

  Future<void> selectDiseaseFocus(DiseaseFocus diseaseFocus) async {
    state = state.copyWith(selectedDiseaseFocus: diseaseFocus);

    // No longer loading doctors here (simplified flow)
  }

  Future<SelectionResult> completePatientSetup({
    required String patientId,
    required String patientName,
    required String patientEmail,
    String? phone,
    int? age,
    String? gender,
    String? medicalHistory,
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
        phone: phone,
        age: age,
        gender: gender,
        medicalHistory: medicalHistory,
      );

      state = state.copyWith(isLoading: false);
      return const SelectionResult(
        success: true,
        message: 'Đăng ký thành công!',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());

      return SelectionResult(success: false, message: 'Lỗi khi đăng ký: $e');
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
