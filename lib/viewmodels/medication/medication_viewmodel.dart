import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/medication_service.dart';
import '../../data/services/medication_reminder_service.dart';
import 'medication_state.dart';

/// ViewModel cho Medication Screen
class MedicationViewModel extends StateNotifier<MedicationState> {
  final MedicationService _service;
  final MedicationReminderService _reminderService;

  MedicationViewModel(this._service, this._reminderService)
    : super(MedicationState());

  // Toggle hiển thị thuốc đang dùng / tất cả
  void toggleShowActiveOnly() {
    state = state.copyWith(showActiveOnly: !state.showActiveOnly);
  }

  // Đánh dấu ngưng sử dụng
  Future<void> deactivateMedication(String medicationId) async {
    try {
      await _service.deactivateMedication(medicationId);
    } catch (e) {
      state = state.copyWith(error: 'Lỗi khi ngưng sử dụng thuốc: $e');
    }
  }

  // Kích hoạt lại thuốc
  Future<void> activateMedication(String medicationId) async {
    try {
      await _service.activateMedication(medicationId);
    } catch (e) {
      state = state.copyWith(error: 'Lỗi khi kích hoạt lại thuốc: $e');
    }
  }

  // Xóa thuốc và lịch nhắc
  Future<void> deleteMedication(String medicationId) async {
    try {
      // Xóa lịch nhắc trước
      await _reminderService.deleteRemindersByMedication(medicationId);
      // Sau đó xóa thuốc
      await _service.deleteMedication(medicationId);
    } catch (e) {
      state = state.copyWith(error: 'Lỗi khi xóa thuốc: $e');
    }
  }
}

// Provider
final medicationViewModelProvider =
    StateNotifierProvider<MedicationViewModel, MedicationState>((ref) {
      final service = ref.watch(medicationServiceProvider);
      final reminderService = ref.watch(medicationReminderServiceProvider);
      return MedicationViewModel(service, reminderService);
    });
