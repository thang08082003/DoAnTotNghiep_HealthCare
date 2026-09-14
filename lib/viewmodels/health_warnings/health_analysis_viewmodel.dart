import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/health_analysis_repository.dart';
import '../../data/models/health_analysis_record.dart';
import 'health_analysis_state.dart';

class HealthAnalysisViewModel extends StateNotifier<HealthAnalysisState> {
  final HealthAnalysisRepository _repository;

  HealthAnalysisViewModel(this._repository)
    : super(const HealthAnalysisState());

  // Analyze health data from Firebase (no syncing needed)
  // Phân tích dữ liệu trực tiếp từ Firebase
  // Luồng: Health Connect → SQLite → Firebase (đồng bộ ở màn hình Health Connect)
  //        Firebase → Phân tích (ở đây) - đọc trực tiếp từ Firebase
  Future<void> analyzeOnly() async {
    try {
      // Start analyzing
      state = state.copyWith(isSyncing: true, error: null);

      // Phân tích dữ liệu từ Firebase (repository sẽ query từ Firebase)
      final now = DateTime.now();

      // Analyze heart rate from Firebase
      final heartRateAnalysis = await _repository.analyzeHeartRate();

      // Analyze SpO2 from Firebase
      final spo2Analysis = await _repository.analyzeSpO2();

      // Analyze sleep from Firebase
      final sleepAnalysis = await _repository.analyzeSleep();

      // Lưu kết quả phân tích lên Firebase
      await _repository.saveAnalysisResult(
        heartRateAnalysis: heartRateAnalysis,
        spo2Analysis: spo2Analysis,
        sleepAnalysis: sleepAnalysis,
      );

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

      // Load lịch sử phân tích từ Firebase
      final history = await _repository.loadAnalysisHistory();

      state = state.copyWith(isLoading: false, analysisHistory: history);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Delete a record from history by index
  Future<void> deleteRecord(int index) async {
    if (index < 0 || index >= state.analysisHistory.length) return;

    try {
      final recordToDelete = state.analysisHistory[index];

      // Xóa trên Firebase
      await _repository.deleteAnalysisResult(recordToDelete.id);

      // Xóa trong state
      final updatedHistory = List<HealthAnalysisRecord>.from(
        state.analysisHistory,
      );
      updatedHistory.removeAt(index);
      state = state.copyWith(analysisHistory: updatedHistory);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

// Provider for the ViewModel
final healthAnalysisViewModelProvider =
    StateNotifierProvider<HealthAnalysisViewModel, HealthAnalysisState>((ref) {
      final repository = HealthAnalysisRepository();
      return HealthAnalysisViewModel(repository);
    });
