import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'unified_sync_service.dart';

/// Dịch vụ đồng bộ thụ động sử dụng Flutter WorkManager
/// Thay thế native WorkManager, dùng UnifiedSyncService để đồng bộ
class PassiveSyncService {
  static final PassiveSyncService _instance = PassiveSyncService._internal();
  factory PassiveSyncService() => _instance;
  PassiveSyncService._internal();

  static const String _taskName = 'passive_health_sync';
  static const String _enabledKey = 'passive_sync_enabled';
  static const Duration _syncInterval = Duration(minutes: 15);

  final UnifiedSyncService _syncService = UnifiedSyncService();

  /// Kiểm tra xem passive sync có đang bật không
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true; // Mặc định bật
  }

  /// Bật passive sync
  Future<void> enable() async {
    debugPrint('🟢 [PassiveSync] Đang bật...');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);

      // Register periodic task
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: _syncInterval,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
      );

      debugPrint('✅ [PassiveSync] Đã bật - sẽ sync mỗi 15 phút');
    } catch (e) {
      debugPrint('❌ [PassiveSync] Lỗi khi bật: $e');
      rethrow;
    }
  }

  /// Tắt passive sync
  Future<void> disable() async {
    debugPrint('🔴 [PassiveSync] Đang tắt...');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, false);

      await Workmanager().cancelByUniqueName(_taskName);

      debugPrint('✅ [PassiveSync] Đã tắt');
    } catch (e) {
      debugPrint('❌ [PassiveSync] Lỗi khi tắt: $e');
      rethrow;
    }
  }

  /// Toggle passive sync
  Future<bool> toggle() async {
    final enabled = await isEnabled();
    if (enabled) {
      await disable();
      return false;
    } else {
      await enable();
      return true;
    }
  }

  /// Thực hiện đồng bộ thụ động (được gọi bởi WorkManager)
  /// Đây là static method để WorkManager có thể gọi từ background
  static Future<void> performPassiveSync() async {
    debugPrint('⚡ [PassiveSync] WorkManager đang thực thi...');

    try {
      // Check if enabled
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_enabledKey) ?? true;

      if (!enabled) {
        debugPrint('⏸️ [PassiveSync] Đã tắt, bỏ qua sync');
        return;
      }

      // Thực hiện đồng bộ
      final syncService = UnifiedSyncService();
      final result = await syncService.syncPassive();

      debugPrint('✅ [PassiveSync] Hoàn tất: ${result.message}');

      // Lưu thời gian sync cuối
      await prefs.setInt(
        'last_passive_sync',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e, stack) {
      debugPrint('❌ [PassiveSync] Lỗi: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// Lấy thời gian sync cuối cùng
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_passive_sync');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Đồng bộ ngay một lần (không phải background task)
  Future<SyncResultDetail> syncNow() async {
    debugPrint('🚀 [PassiveSync] Đồng bộ ngay lập tức (1 ngày)...');

    try {
      final result = await _syncService.syncImmediately(days: 1);

      // Lưu thời gian sync
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_immediate_sync',
        DateTime.now().millisecondsSinceEpoch,
      );

      return result;
    } catch (e, stack) {
      debugPrint('❌ [PassiveSync] Lỗi sync ngay: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }
}
