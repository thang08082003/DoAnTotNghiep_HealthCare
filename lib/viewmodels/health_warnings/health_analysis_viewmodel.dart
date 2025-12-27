import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/health_analysis_repository.dart';
import '../../data/models/health_analysis_record.dart';
import 'health_analysis_state.dart';

class HealthAnalysisViewModel extends StateNotifier<HealthAnalysisState> {
  final HealthAnalysisRepository _repository;

  HealthAnalysisViewModel(this._repository)
    : super(const HealthAnalysisState());

  // Sync and analyze all health data
  Future<void> syncAndAnalyze() async {
    try {
      // Start syncing
      state = state.copyWith(isSyncing: true, error: null);

      // Step 1: Sync data from Health Connect
      await _repository.syncHealthData();

      // Step 2: Analyze the synced data
      final now = DateTime.now();

      // Analyze heart rate
      final heartRateAnalysis = await _repository.analyzeHeartRate();

      // Analyze SpO2
      final spo2Analysis = await _repository.analyzeSpO2();

      // Analyze sleep
      final sleepAnalysis = await _repository.analyzeSleep();

      // Create new analysis record
      final newRecord = HealthAnalysisRecord(
        id: now.millisecondsSinceEpoch.toString(),
        timestamp: now,
        heartRateAnalysis: heartRateAnalysis,
        spo2Analysis: spo2Analysis,
        sleepAnalysis: sleepAnalysis,
      );

      // Add to history (newest first)
      final updatedHistory = [newRecord, ...state.analysisHistory];

      // Update last sync time
      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: now,
        analysisHistory: updatedHistory,
      );
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
      rethrow;
    }
  }

  // Load existing analysis without syncing
  Future<void> loadExistingData() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      // Just load, don't create new records
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Delete a record from history by index
  void deleteRecord(int index) {
    final updatedHistory = List<HealthAnalysisRecord>.from(
      state.analysisHistory,
    );
    if (index >= 0 && index < updatedHistory.length) {
      updatedHistory.removeAt(index);
      state = state.copyWith(analysisHistory: updatedHistory);
    }
  }
}

// Provider for the ViewModel
final healthAnalysisViewModelProvider =
    StateNotifierProvider<HealthAnalysisViewModel, HealthAnalysisState>((ref) {
      final repository = HealthAnalysisRepository();
      return HealthAnalysisViewModel(repository);
    });
