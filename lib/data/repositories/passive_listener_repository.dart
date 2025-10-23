import '../services/android_passive_listener_service.dart';

class PassiveListenerRepository {
  void enable() {
    AndroidPassiveListenerService.enable();
  }

  void disable() {
    AndroidPassiveListenerService.disable();
  }
}
