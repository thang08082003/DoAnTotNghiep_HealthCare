import '../services/incoming_call_listener.dart';

class IncomingCallRepository {
  void start(String userId) {
    IncomingCallListener.start(userId);
  }

  void stop() {
    IncomingCallListener.stop();
  }
}
