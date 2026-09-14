import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/health_analysis_repository.dart';
import 'patient_health_analysis_state.dart';

class PatientHealthAnalysisViewModel
    extends StateNotifier<PatientHealthAnalysisState> {
  final HealthAnalysisRepository _repository;

  PatientHealthAnalysisViewModel(this._repository)
    : super(const PatientHealthAnalysisState.initial());

  Future<void> load(String userId) async {
    if (userId.isEmpty) {
      state = state.copyWith(error: 'Thiếu mã bệnh nhân');
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final history = await _repository.loadAnalysisHistoryForUser(userId);
      state = state.copyWith(loading: false, history: history);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final patientHealthAnalysisViewModelProvider = StateNotifierProvider.autoDispose
    .family<PatientHealthAnalysisViewModel, PatientHealthAnalysisState, String>(
      (ref, userId) {
        final repository = HealthAnalysisRepository();
        final vm = PatientHealthAnalysisViewModel(repository);
        if (userId.isNotEmpty) {
          // ignore: unawaited_futures
          vm.load(userId);
        }
        return vm;
      },
    );
