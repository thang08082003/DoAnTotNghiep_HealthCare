import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/local_notifications_service.dart';
import '../../data/services/android_foreground_service.dart';
import '../../data/services/incoming_call_listener.dart';

class LocalNotificationsViewModel {
  Future<void> initialize() {
    return LocalNotificationsService.initialize();
  }

  Future<void> startForUser(String userId) async {
    await LocalNotificationsService.startListeningUserNotifications(userId);
    await LocalNotificationsService.handleInitialNotificationLaunch();
    await AndroidForegroundService.stop();
    AndroidForegroundService.ensureTapListener();
    IncomingCallListener.start(userId);
  }

  Future<void> stopAll() async {
    IncomingCallListener.stop();
    await AndroidForegroundService.stop();
    await LocalNotificationsService.stop();
  }
}

final localNotificationsViewModelProvider =
    Provider<LocalNotificationsViewModel>((ref) {
      return LocalNotificationsViewModel();
    });
