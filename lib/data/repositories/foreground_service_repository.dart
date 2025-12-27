import '../services/android_foreground_service.dart';

class ForegroundServiceRepository {
  Future<void> start(String userId) {
    return AndroidForegroundService.start(userId);
  }

  Future<void> stop() {
    return AndroidForegroundService.stop();
  }

  void ensureTapListener() {
    AndroidForegroundService.ensureTapListener();
  }
}
