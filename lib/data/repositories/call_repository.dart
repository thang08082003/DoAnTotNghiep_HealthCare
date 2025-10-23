import '../services/call_service.dart';
import '../models/call_session.dart';

class CallRepository {
  final CallService _service;
  CallRepository({CallService? service}) : _service = service ?? CallService();

  Future<String> createOutgoingCall({
    required String callerId,
    required String calleeId,
    required String channelName,
  }) {
    return _service.createOutgoingCall(
      callerId: callerId,
      calleeId: calleeId,
      channelName: channelName,
    );
  }

  Stream<CallSession?> watchCall(String callId) {
    return _service.watchCall(callId);
  }
}
