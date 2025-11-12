import 'package:flutter/foundation.dart';
import '../data/services/local_notifications_service.dart';
import '../data/services/incoming_call_listener.dart';
import '../data/services/android_foreground_service.dart';

/// Centralized cleanup service to ensure all listeners and services
/// are properly stopped when logging out or switching users.
class CleanupService {
  /// Stop all active listeners and services.
  /// CRITICAL: Must be called BEFORE Firebase Auth signOut to prevent
  /// permission denied errors and ensure clean state transition.
  static Future<void> stopAllListeners() async {
    debugPrint('[CleanupService] Stopping all listeners and services...');

    try {
      // Stop incoming call listener
      IncomingCallListener.stop();
      debugPrint('[CleanupService] ✓ Stopped IncomingCallListener');
    } catch (e) {
      debugPrint('[CleanupService] ✗ Error stopping IncomingCallListener: $e');
    }

    try {
      // Stop local notifications listener
      await LocalNotificationsService.stop();
      debugPrint('[CleanupService] ✓ Stopped LocalNotificationsService');
    } catch (e) {
      debugPrint(
        '[CleanupService] ✗ Error stopping LocalNotificationsService: $e',
      );
    }

    try {
      // Stop Android foreground service
      await AndroidForegroundService.stop();
      debugPrint('[CleanupService] ✓ Stopped AndroidForegroundService');
    } catch (e) {
      debugPrint(
        '[CleanupService] ✗ Error stopping AndroidForegroundService: $e',
      );
    }

    debugPrint('[CleanupService] All listeners and services stopped');
  }
}
