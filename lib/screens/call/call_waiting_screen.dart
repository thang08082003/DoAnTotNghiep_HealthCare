import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/call_service.dart';
import '../../data/models/call_session.dart';
import '../../data/services/local_notifications_service.dart';
import '../../data/services/notification_service.dart' as app_notif;
import 'video_call_screen.dart';

class CallWaitingScreen extends ConsumerStatefulWidget {
  final String callId;
  final String channelName;
  const CallWaitingScreen({
    super.key,
    required this.callId,
    required this.channelName,
  });

  @override
  ConsumerState<CallWaitingScreen> createState() => _CallWaitingScreenState();
}

class _CallWaitingScreenState extends ConsumerState<CallWaitingScreen> {
  final _service = CallService();
  StreamSubscription? _sub;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _sub = _service.watchCall(widget.callId).listen((session) async {
      if (session == null || _ended) return;
      if (!mounted) return;
      if (session.status == CallStatus.accepted) {
        // Go to video call
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              channelName: widget.channelName,
              callId: widget.callId,
            ),
          ),
        );
      } else if (session.status == CallStatus.declined ||
          session.status == CallStatus.ended) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuộc gọi không được kết nối')),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _cancelCall() async {
    if (_ended) return;
    _ended = true;
    // Best-effort: cancel any incoming-call notification (on this device if present)
    await LocalNotificationsService.cancelIncomingCallNotification(
      widget.callId,
    ).catchError((_) {});
    await _service.end(widget.callId);
    // Clean related incoming_call notifications in Firestore
    app_notif.NotificationService.deleteIncomingCallNotificationsByCallId(
      widget.callId,
    ).catchError((_) {});
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Đang gọi...'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _cancelCall,
                icon: const Icon(Icons.call_end),
                label: const Text('Hủy cuộc gọi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
