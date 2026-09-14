import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/incoming_call_provider.dart';
import '../screens/call/video_call_incoming_screen.dart';
import '../data/models/call_session.dart';

/// Widget that listens for incoming calls and automatically shows the incoming call screen
/// when the app is in foreground
class IncomingCallListener extends ConsumerStatefulWidget {
  final Widget child;

  const IncomingCallListener({super.key, required this.child});

  @override
  ConsumerState<IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<IncomingCallListener> {
  String? _lastShownCallId;

  @override
  Widget build(BuildContext context) {
    // Watch for incoming calls
    ref.listen<AsyncValue<CallSession?>>(incomingCallProvider, (
      previous,
      next,
    ) {
      next.whenData((callSession) async {
        if (callSession == null) {
          // Reset when no call is ringing - this allows new calls to be shown
          _lastShownCallId = null;
          return;
        }

        // Prevent showing the same call multiple times
        if (_lastShownCallId == callSession.id) return;
        _lastShownCallId = callSession.id;

        // Fetch caller name
        String callerName = callSession.callerId;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(callSession.callerId)
              .get();
          if (userDoc.exists) {
            callerName =
                userDoc.data()?['name'] as String? ?? callSession.callerId;
          }
        } catch (_) {
          // Fallback to callerId if fetch fails
        }

        // Show incoming call screen
        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoCallIncomingScreen(
              callId: callSession.id,
              channelName: callSession.channelName,
              callerName: callerName,
            ),
            fullscreenDialog: true,
          ),
        );
      });
    });

    return widget.child;
  }
}
