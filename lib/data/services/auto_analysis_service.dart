import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/health_analysis_repository.dart';

/// Service quản lý phân tích sức khỏe tự động
class AutoAnalysisService {
  static const String _autoAnalysisKey = 'auto_analysis_enabled';
  static const String _taskName = 'health_auto_analysis_task';

  AutoAnalysisService();

  /// Kiểm tra xem auto-analysis có được bật hay không
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoAnalysisKey) ?? false;
  }

  /// Bật auto-analysis
  Future<void> enable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAnalysisKey, true);
    await _schedulePeriodicAnalysis();
  }

  /// Tắt auto-analysis
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAnalysisKey, false);
    await _cancelPeriodicAnalysis();
  }

  /// Lên lịch phân tích định kỳ mỗi 30 phút
  Future<void> _schedulePeriodicAnalysis() async {
    try {
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: const Duration(minutes: 30), // Mỗi 30 phút
        initialDelay: const Duration(
          minutes: 1,
        ), // Chờ 1 phút trước khi chạy lần đầu
        constraints: Constraints(
          networkType: NetworkType.connected, // Cần kết nối mạng
        ),
      );
    } catch (e) {
      print('Error scheduling periodic analysis: $e');
      rethrow;
    }
  }

  /// Hủy phân tích định kỳ
  Future<void> _cancelPeriodicAnalysis() async {
    try {
      await Workmanager().cancelByUniqueName(_taskName);
    } catch (e) {
      print('Error cancelling periodic analysis: $e');
      // Don't rethrow for cancel operation
    }
  }

  /// Thực hiện phân tích (được gọi bởi WorkManager)
  static Future<void> performAnalysis() async {
    try {
      final repository = HealthAnalysisRepository();

      // Sync dữ liệu từ Health Connect
      await repository.syncHealthData();

      // Phân tích heart rate
      await repository.analyzeHeartRate();

      // Phân tích SpO2
      await repository.analyzeSpO2();

      // Phân tích sleep
      await repository.analyzeSleep();

      print('Auto-analysis completed successfully');
    } catch (e) {
      print('Auto-analysis error: $e');
      rethrow;
    }
  }
}

/// Provider cho AutoAnalysisService
final autoAnalysisServiceProvider = Provider<AutoAnalysisService>((ref) {
  return AutoAnalysisService();
});

/// Provider để theo dõi trạng thái auto-analysis
final autoAnalysisEnabledProvider =
    StateNotifierProvider<AutoAnalysisNotifier, bool>((ref) {
      return AutoAnalysisNotifier(ref.read(autoAnalysisServiceProvider));
    });

/// StateNotifier để quản lý trạng thái auto-analysis
class AutoAnalysisNotifier extends StateNotifier<bool> {
  final AutoAnalysisService _service;

  AutoAnalysisNotifier(this._service) : super(false) {
    _loadState();
  }

  /// Tải trạng thái hiện tại
  Future<void> _loadState() async {
    state = await _service.isEnabled();
  }

  /// Bật/tắt auto-analysis
  Future<void> toggle(bool enabled) async {
    if (enabled) {
      await _service.enable();
    } else {
      await _service.disable();
    }
    state = enabled;
  }
}
