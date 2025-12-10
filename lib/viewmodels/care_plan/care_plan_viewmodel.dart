import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/care_plan_model.dart';
import '../../data/services/care_plan_service.dart';

import 'care_plan_state.dart';

// ViewModel class để xử lý business logic
class CarePlanViewModel extends StateNotifier<CarePlanState> {
  final CarePlanService _carePlanService;
  final String userId;

  CarePlanViewModel(this._carePlanService, this.userId)
    : super(CarePlanState(selectedDate: DateTime.now()));

  // Cập nhật ngày được chọn
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  // Stream để lấy danh sách health goals theo ngày đã chọn
  Stream<List<HealthGoal>> getHealthGoalsStream() {
    return _carePlanService.getHealthGoalsForDate(userId, state.selectedDate);
  }

  // Tạo mục tiêu mới
  Future<void> createHealthGoal({
    required String title,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _carePlanService.createHealthGoal(
        userId: userId,
        title: title,
        description: description,
        targetDate: state.selectedDate,
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tạo mục tiêu: $e',
      );
      rethrow;
    }
  }

  // Toggle hoàn thành mục tiêu
  Future<void> toggleGoalCompletion(String goalId, bool isCompleted) async {
    try {
      await _carePlanService.toggleGoalCompletion(goalId, !isCompleted);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Không thể cập nhật mục tiêu: $e');
      rethrow;
    }
  }

  // Xóa mục tiêu
  Future<void> deleteHealthGoal(String goalId) async {
    try {
      await _carePlanService.deleteHealthGoal(goalId);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Không thể xóa mục tiêu: $e');
      rethrow;
    }
  }
}

// Provider cho ViewModel
final carePlanViewModelProvider =
    StateNotifierProvider.family<CarePlanViewModel, CarePlanState, String>((
      ref,
      userId,
    ) {
      final carePlanService = ref.watch(carePlanServiceProvider);
      return CarePlanViewModel(carePlanService, userId);
    });
