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
  /// CHỈ phân tích dữ liệu đã có trong Firebase, KHÔNG đồng bộ
  static Future<void> performAnalysis() async {
    try {
      print('🔍 [AutoAnalysis] Bắt đầu phân tích tự động...');

      // Thực hiện phân tích dữ liệu có sẵn trong Firebase
      final repository = HealthAnalysisRepository();

      // Phân tích heart rate
      await repository.analyzeHeartRate();
      print('✅ [AutoAnalysis] Đã phân tích heart rate');

      // Phân tích SpO2
      await repository.analyzeSpO2();
      print('✅ [AutoAnalysis] Đã phân tích SpO2');

      // Phân tích sleep
      await repository.analyzeSleep();
      print('✅ [AutoAnalysis] Đã phân tích sleep');

      print('🎉 [AutoAnalysis] Hoàn tất phân tích tự động');
    } catch (e, stack) {
      print('❌ [AutoAnalysis] Lỗi: $e');
      print('Stack: $stack');
      rethrow;
    }
  }
}

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

  /// Bật/tắt auto-analysis với bool parameter
  Future<void> toggle(bool enabled) async {
    if (enabled) {
      await _service.enable();
    } else {
      await _service.disable();
    }
    state = enabled;
  }

  /// Toggle auto-analysis (bật thành tắt, tắt thành bật)
  Future<void> toggleSwitch() async {
    if (state) {
      await _service.disable();
    } else {
      await _service.enable();
    }
    state = !state;
  }
}
