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
