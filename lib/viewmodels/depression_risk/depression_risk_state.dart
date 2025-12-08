/// Enum cho time range filter
enum TimeRange { day, week, month }

/// State cho Depression Risk Screen
class DepressionRiskState {
  final bool isLoading;
  final String? error;
  final TimeRange timeRange; // Lọc theo ngày/tuần/tháng

  const DepressionRiskState({
    this.isLoading = false,
    this.error,
    this.timeRange = TimeRange.week,
  });

  DepressionRiskState copyWith({
    bool? isLoading,
    String? error,
    TimeRange? timeRange,
  }) {
    return DepressionRiskState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      timeRange: timeRange ?? this.timeRange,
    );
  }
}
