import '../../data/models/health_analysis_record.dart';

class PatientHealthAnalysisState {
  final bool loading;
  final String? error;
  final List<HealthAnalysisRecord> history;

  const PatientHealthAnalysisState({
    required this.loading,
    required this.error,
    required this.history,
  });

  const PatientHealthAnalysisState.initial()
      : loading = false,
        error = null,
        history = const [];

  PatientHealthAnalysisState copyWith({
    bool? loading,
    String? error,
    List<HealthAnalysisRecord>? history,
  }) {
    return PatientHealthAnalysisState(
      loading: loading ?? this.loading,
      error: error,
      history: history ?? this.history,
    );
  }
}
