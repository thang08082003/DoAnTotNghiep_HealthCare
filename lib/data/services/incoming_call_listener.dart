import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../router/navigation_service.dart';
import '../../screens/call/video_call_incoming_screen.dart';
import 'local_notifications_service.dart';
import '../models/call_session.dart';
import 'user_service.dart';

class IncomingCallListener {
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  static final Set<String> _notified = <String>{};

  static void start(String currentUserId) {
    stop();
    final db = FirebaseFirestore.instance;
    _sub = db
        .collection('call_sessions')
        .where('calleeId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((qs) async {
          // Handle added and removed changes so we can show and cancel notifications
          for (final change in qs.docChanges) {
            final doc = change.doc;
            if (change.type == DocumentChangeType.added) {
              if (_notified.contains(doc.id)) continue;
              final session = CallSession.fromDoc(doc);
              String callerName = session.callerId;
              try {
                final user = await UserService().getUserById(session.callerId);
                if (user?.name != null && user!.name.trim().isNotEmpty) {
                  callerName = user.name.trim();
                }
              } catch (_) {}
              // If app is in foreground, show the incoming call screen directly.
              final state = WidgetsBinding.instance.lifecycleState;
              if (state == AppLifecycleState.resumed) {
                final nav = NavigationService.navigatorKey.currentState;
                if (nav != null) {
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) => VideoCallIncomingScreen(
                        callId: session.id,
                        channelName: session.channelName,
                        callerName: callerName,
                      ),
                    ),
                  );
                }
              } else {
                // App is not in foreground; let native Android foreground service handle ringing.
              }
              _notified.add(doc.id);
            } else if (change.type == DocumentChangeType.removed) {
              // Ringing doc removed (status changed or call ended): cancel notif
              await LocalNotificationsService.cancelIncomingCallNotification(
                doc.id,
              );
              _notified.remove(doc.id);
            }
          }
        });
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
    _notified.clear();
  }
}
