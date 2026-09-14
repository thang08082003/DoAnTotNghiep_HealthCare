import '../../../data/models/health_analysis_record.dart';

class HealthAnalysisState {
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final List<HealthAnalysisRecord> analysisHistory;
  final DateTime? lastSyncTime;

  const HealthAnalysisState({
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.analysisHistory = const [],
    this.lastSyncTime,
  });

  HealthAnalysisState copyWith({
    bool? isLoading,
    bool? isSyncing,
    String? error,
    List<HealthAnalysisRecord>? analysisHistory,
    DateTime? lastSyncTime,
  }) {
    return HealthAnalysisState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      analysisHistory: analysisHistory ?? this.analysisHistory,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  bool get hasData => analysisHistory.isNotEmpty;
}
