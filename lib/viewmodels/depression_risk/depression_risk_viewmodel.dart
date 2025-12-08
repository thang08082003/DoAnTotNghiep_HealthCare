import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/depression_risk_service.dart';
import '../../data/models/phq9_question_model.dart';
import 'depression_risk_state.dart';

/// ViewModel cho Depression Risk Screen
class DepressionRiskViewModel extends StateNotifier<DepressionRiskState> {
  final DepressionRiskService _service;

  DepressionRiskViewModel(this._service) : super(const DepressionRiskState());

  /// Thay đổi time range filter
  void setTimeRange(TimeRange range) {
    state = state.copyWith(timeRange: range);
  }

  /// Tạo đánh giá mới từ câu trả lời PHQ-9
  Future<void> createAssessment({
    required String userId,
    required List<PHQ9Answer> answers,
    String? note,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.createAssessment(
        userId: userId,
        answers: answers,
        note: note,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Lỗi khi lưu đánh giá: $e',
      );
    }
  }

  /// Xóa đánh giá
  Future<void> deleteAssessment(String assessmentId) async {
    try {
      await _service.deleteAssessment(assessmentId);
    } catch (e) {
      state = state.copyWith(error: 'Lỗi khi xóa đánh giá: $e');
    }
  }

  /// Tính toán start/end date dựa trên TimeRange
  DateTimeRange getDateRange(TimeRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (range) {
      case TimeRange.day:
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case TimeRange.week:
        final weekAgo = today.subtract(const Duration(days: 7));
        return DateTimeRange(start: weekAgo, end: today.add(const Duration(days: 1)));
      case TimeRange.month:
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return DateTimeRange(start: monthAgo, end: today.add(const Duration(days: 1)));
    }
  }
}

/// Helper class cho date range
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange({required this.start, required this.end});
}

/// Provider cho DepressionRiskViewModel
final depressionRiskViewModelProvider =
    StateNotifierProvider<DepressionRiskViewModel, DepressionRiskState>((ref) {
  final service = ref.watch(depressionRiskServiceProvider);
  return DepressionRiskViewModel(service);
});
