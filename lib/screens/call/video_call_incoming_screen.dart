import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/call_service.dart';
import '../../data/models/call_session.dart';
import '../../data/services/local_notifications_service.dart';
import '../../data/services/notification_service.dart' as app_notif;
import 'video_call_screen.dart';

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
      if (!mounted || _sub == null) return; // Don't process if stream cancelled
      if (session == null) {
        // Call doc removed or not found; close screen
        if (!_handled) _handled = true;
        if (mounted) Navigator.of(context).pop();
        return;
      }
      switch (session.status) {
        case CallStatus.accepted:
          // Don't navigate from stream listener if user already handled it via button
          if (_handled) return;
          // Stream-triggered accept (e.g., accepted from another device)
          // Just let it be, don't auto-navigate
          return;
        case CallStatus.declined:
        case CallStatus.ended:
          // Call ended - close this screen
          if (_handled) {
            // If already handled (user accepted then call ended), just close
            if (mounted) Navigator.of(context).pop();
          } else {
            // User declined or caller ended before answer
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cuộc gọi đã kết thúc')),
              );
              Navigator.of(context).pop();
            }
          }
          _handled = true;
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

    // Cancel stream to prevent further updates while in call
    await _sub?.cancel();
    _sub = null;

    await LocalNotificationsService.cancelIncomingCallNotification(
      widget.callId,
    ).catchError((_) {});
    await _service.accept(widget.callId).catchError((_) {});
    // Clean related incoming_call notifications in Firestore
    app_notif.NotificationService.deleteIncomingCallNotificationsByCallId(
      widget.callId,
    ).catchError((_) {});
    if (!mounted) return;

    // Use push instead of pushReplacement
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          channelName: widget.channelName,
          callId: widget.callId,
        ),
      ),
    );

    // When returning from VideoCallScreen, close this screen too
    if (mounted) {
      Navigator.of(context).pop();
    }
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
    if (mounted) Navigator.of(context).pop();
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
