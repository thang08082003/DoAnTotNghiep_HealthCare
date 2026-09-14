import 'package:flutter/foundation.dart';
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
