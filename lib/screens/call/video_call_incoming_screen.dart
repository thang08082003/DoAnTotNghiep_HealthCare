import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/call_service.dart';
import '../../data/models/call_session.dart';
import '../../data/services/local_notifications_service.dart';
import '../../data/services/notification_service.dart' as app_notif;
import 'video_call_screen.dart';
import '../../router/navigation_service.dart';

class VideoCallIncomingScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final String callerName;

  const VideoCallIncomingScreen({
    super.key,
    required this.callId,
    required this.channelName,
    required this.callerName,
  });

  @override
  State<VideoCallIncomingScreen> createState() =>
      _VideoCallIncomingScreenState();
}

class _VideoCallIncomingScreenState extends State<VideoCallIncomingScreen> {
  final _service = CallService();
  StreamSubscription? _sub;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _sub = _service.watchCall(widget.callId).listen((session) async {
      if (!mounted || _handled) return;
      if (session == null) {
        // Call doc removed or not found; close screen via root navigator
        NavigationService.navigator?.pop();
        return;
      }
      switch (session.status) {
        case CallStatus.accepted:
          _handled = true;
          await LocalNotificationsService.cancelIncomingCallNotification(
            widget.callId,
          ).catchError((_) {});
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => VideoCallScreen(
                channelName: widget.channelName,
                callId: widget.callId,
              ),
            ),
          );
          break;
        case CallStatus.declined:
        case CallStatus.ended:
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cuộc gọi đã kết thúc')));
          NavigationService.navigator?.pop();
          break;
        case CallStatus.ringing:
          // keep waiting
          break;
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_handled) return;
    _handled = true;
    await LocalNotificationsService.cancelIncomingCallNotification(
      widget.callId,
    ).catchError((_) {});
    await _service.accept(widget.callId).catchError((_) {});
    // Clean related incoming_call notifications in Firestore
    app_notif.NotificationService.deleteIncomingCallNotificationsByCallId(
      widget.callId,
    ).catchError((_) {});
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          channelName: widget.channelName,
          callId: widget.callId,
        ),
      ),
    );
  }

  Future<void> _decline() async {
    if (_handled) return;
    _handled = true;
    await LocalNotificationsService.cancelIncomingCallNotification(
      widget.callId,
    ).catchError((_) {});
    await _service.decline(widget.callId).catchError((_) {});
    // Clean related incoming_call notifications in Firestore
    app_notif.NotificationService.deleteIncomingCallNotificationsByCallId(
      widget.callId,
    ).catchError((_) {});
    NavigationService.navigator?.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.call, size: 72, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                widget.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Cuộc gọi đến',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                    ),
                    onPressed: _decline,
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                    ),
                    onPressed: _accept,
                    child: const Icon(
                      Icons.call,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
