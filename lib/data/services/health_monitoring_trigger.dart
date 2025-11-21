import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/health_monitoring_provider.dart';

/// Service to handle health monitoring triggers from background workers
class HealthMonitoringTrigger {
  static const MethodChannel _channel = MethodChannel(
    'com.example.healthcare/health_monitoring',
  );

  /// Initialize listener for background health monitoring triggers
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'checkHealthMonitoring') {
        final userId = call.arguments['userId'] as String?;
        if (userId != null) {
          await _handleHealthCheck(userId);
        }
      }
    });
  }

  /// Handle health monitoring check triggered from background
  static Future<void> _handleHealthCheck(String userId) async {
    try {
      print('[HealthMonitoringTrigger] Check triggered for user: $userId');

      // Verify user is still authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid != userId) {
        print('[HealthMonitoringTrigger] User not authenticated, skipping');
        return;
      }

      // Check if should run (respects 6-hour interval)
      final shouldRun = await shouldRunAIMonitoring(userId);
      if (!shouldRun) {
        print('[HealthMonitoringTrigger] Not time yet, skipping');
        return;
      }

      // Run monitoring
      await runImmediateHealthCheck(userId);
      print('[HealthMonitoringTrigger] Check completed successfully');
    } catch (e) {
      print('[HealthMonitoringTrigger] Error: $e');
    }
  }

  /// Manually trigger a health check (for testing)
  static Future<void> triggerManualCheck() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _channel.invokeMethod('triggerHealthCheck', {'userId': userId});
    } catch (e) {
      print('[HealthMonitoringTrigger] Manual trigger failed: $e');
    }
  }
}
