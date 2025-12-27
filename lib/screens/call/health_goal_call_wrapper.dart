import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/call_service.dart';
import '../../data/models/call_session.dart';
import '../../data/services/local_notifications_service.dart';
import '../../data/services/notification_service.dart' as app_notif;
import 'video_call_screen.dart';

/// Wrapper screen để quản lý call flow cho health goal
/// Sau khi video call kết thúc, hiển thị dialog hỏi kết quả
/// Trả về Map<String, dynamic>? với keys: 'resolved' (bool), 'cancelled' (bool)
class HealthGoalCallWrapper extends ConsumerStatefulWidget {
  final String callId;
  final String channelName;

  const HealthGoalCallWrapper({
    super.key,
    required this.callId,
    required this.channelName,
  });

  @override
  ConsumerState<HealthGoalCallWrapper> createState() =>
      _HealthGoalCallWrapperState();
}

class _HealthGoalCallWrapperState extends ConsumerState<HealthGoalCallWrapper> {
  final _service = CallService();
  StreamSubscription? _sub;
  bool _ended = false;
  bool _inVideoCall = false;

  @override
  void initState() {
    super.initState();
    _sub = _service.watchCall(widget.callId).listen((session) async {
      if (session == null || _ended) return;
      if (!mounted) return;

      if (session.status == CallStatus.accepted && !_inVideoCall) {
        _inVideoCall = true;
        // Chuyển sang video call
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              channelName: widget.channelName,
              callId: widget.callId,
            ),
          ),
        );

        // Sau khi video call kết thúc, hiển thị dialog
        if (!mounted) return;
        final resolved = await _showPostCallDialog();

        // Pop wrapper với kết quả
        if (mounted) {
          Navigator.of(context).pop({'resolved': resolved, 'cancelled': false});
        }
      } else if (session.status == CallStatus.declined ||
          session.status == CallStatus.ended) {
        if (!_inVideoCall && mounted) {
          // Call bị từ chối hoặc hủy trước khi vào video call
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuộc gọi không được kết nối')),
          );
          Navigator.of(context).pop({'resolved': null, 'cancelled': true});
        }
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
    await LocalNotificationsService.cancelIncomingCallNotification(
      widget.callId,
    ).catchError((_) {});
    await _service.end(widget.callId);
    app_notif.NotificationService.deleteIncomingCallNotificationsByCallId(
      widget.callId,
    ).catchError((_) {});
    if (mounted) {
      Navigator.of(context).pop({'resolved': null, 'cancelled': true});
    }
  }

  Future<bool?> _showPostCallDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Kết quả trao đổi'),
        content: const Text(
          'Vấn đề về mục tiêu này đã được giải quyết qua cuộc gọi video chưa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Chưa giải quyết',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đã giải quyết'),
          ),
        ],
      ),
    );
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
