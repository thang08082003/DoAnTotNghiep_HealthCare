import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/android_foreground_service.dart';

class LocalNotificationsViewModel {
  Future<void> startForUser(String userId) async {
    // Only use background service for all notifications
    await AndroidForegroundService.stop(); // Stop first to restart
    await AndroidForegroundService.start(userId); // Start background service
    AndroidForegroundService.ensureTapListener();
  }

  Future<void> stopAll() async {
    await AndroidForegroundService.stop();
  }
}

final localNotificationsViewModelProvider =
    Provider<LocalNotificationsViewModel>((ref) {
      return LocalNotificationsViewModel();
    });
