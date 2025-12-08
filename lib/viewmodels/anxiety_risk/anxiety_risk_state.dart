/// Enum cho time range filter (dùng chung cho cả Depression và Anxiety)
enum TimeRange { day, week, month }

/// State cho Anxiety Risk Screen
class AnxietyRiskState {
  final bool isLoading;
  final String? error;
  final TimeRange timeRange; // Lọc theo ngày/tuần/tháng

  const AnxietyRiskState({
    this.isLoading = false,
    this.error,
    this.timeRange = TimeRange.week,
  });

  AnxietyRiskState copyWith({
    bool? isLoading,
    String? error,
    TimeRange? timeRange,
  }) {
    return AnxietyRiskState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      timeRange: timeRange ?? this.timeRange,
    );
  }
}
