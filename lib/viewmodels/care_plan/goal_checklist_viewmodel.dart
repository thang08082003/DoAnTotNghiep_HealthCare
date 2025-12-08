import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/care_plan_model.dart';
import '../../data/services/care_plan_service.dart';
import 'goal_checklist_state.dart';

/// ViewModel cho Goal Checklist - Xử lý business logic
class GoalChecklistViewModel extends StateNotifier<GoalChecklistState> {
  final CarePlanService _service;

  GoalChecklistViewModel(this._service, HealthGoal goal)
    : super(GoalChecklistState(goal: goal));

  // Stream để lấy danh sách checklist items
  Stream<List<GoalChecklistItem>> getChecklistItemsStream() {
    return _service.getGoalChecklistItems(state.goal.id);
  }

  // Tạo checklist item mới
  Future<void> createChecklistItem(String title) async {
    if (title.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Vui lòng nhập nội dung');
      return;
    }

    state = state.copyWith(isAddingItem: true, errorMessage: null);

    try {
      final item = GoalChecklistItem(
        id: '',
        goalId: state.goal.id,
        title: title.trim(),
        createdAt: DateTime.now(),
      );

      await _service.createChecklistItem(item);
      state = state.copyWith(isAddingItem: false);
    } catch (e) {
      state = state.copyWith(
        isAddingItem: false,
        errorMessage: 'Không thể tạo mục: $e',
      );
      rethrow;
    }
  }

  // Toggle hoàn thành checklist item
  Future<void> toggleItemCompletion(String itemId, bool isCompleted) async {
    try {
      await _service.toggleChecklistItemCompletion(itemId, !isCompleted);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Không thể cập nhật: $e');
      rethrow;
    }
  }

  // Xóa checklist item
  Future<void> deleteChecklistItem(String itemId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _service.deleteChecklistItem(itemId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể xóa: $e',
      );
      rethrow;
    }
  }

  // Cập nhật tiêu đề checklist item
  Future<void> updateItemTitle(String itemId, String title) async {
    if (title.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Tiêu đề không được để trống');
      return;
    }

    try {
      await _service.updateChecklistItemTitle(itemId, title.trim());
    } catch (e) {
      state = state.copyWith(errorMessage: 'Không thể cập nhật: $e');
      rethrow;
    }
  }

  // Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

// Provider cho ViewModel
final goalChecklistViewModelProvider =
    StateNotifierProvider.family<
      GoalChecklistViewModel,
      GoalChecklistState,
      HealthGoal
    >((ref, goal) {
      final service = ref.watch(carePlanServiceProvider);
      return GoalChecklistViewModel(service, goal);
    });
