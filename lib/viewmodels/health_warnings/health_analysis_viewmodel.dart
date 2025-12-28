import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/health_analysis_repository.dart';
import '../../data/models/health_analysis_record.dart';
import 'health_analysis_state.dart';

class HealthAnalysisViewModel extends StateNotifier<HealthAnalysisState> {
  final HealthAnalysisRepository _repository;

  HealthAnalysisViewModel(this._repository)
    : super(const HealthAnalysisState());

  // Analyze health data (without syncing)
  // Phân tích dữ liệu có sẵn trong SQLite (đã được đồng bộ từ Health Connect)
  // Luồng: Health Connect → SQLite → Firebase (đồng bộ ở màn hình Health Connect)
  //        SQLite → Phân tích (ở đây)
  Future<void> analyzeOnly() async {
    try {
      // Start analyzing
      state = state.copyWith(isSyncing: true, error: null);

      // Phân tích dữ liệu từ SQLite (repository sẽ query từ SQLite)
      final now = DateTime.now();

      // Analyze heart rate from SQLite
      final heartRateAnalysis = await _repository.analyzeHeartRate();

      // Analyze SpO2 from SQLite
      final spo2Analysis = await _repository.analyzeSpO2();

      // Analyze sleep from SQLite
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
