import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../router/navigation_service.dart';
import '../../screens/doctors/doctor_detail_screen.dart';
import '../../screens/patients/patient_detail_screen.dart';
import '../../screens/call/video_call_incoming_screen.dart';
import 'notification_service.dart' as app_notif;
import 'call_service.dart';
import '../../screens/call/video_call_screen.dart';
import 'android_foreground_service.dart';

/// Local notification utilities for handling notification taps and canceling notifications.
/// All notification listening is now handled by native Android background service.
class LocalNotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static int _notificationIdForCall(String callId) {
    // Create a stable positive int id from callId
    final h = callId.hashCode;
    return (h & 0x7fffffff) % 100000000; // keep it within a reasonable range
  }

  static Future<void> cancelIncomingCallNotification(String callId) async {
    final id = _notificationIdForCall(callId);
    // Cancel both in Flutter plugin and native notification manager
    await _plugin.cancel(id);
    await AndroidForegroundService.cancelIncomingCallNotification(callId);
  }

  static void handleNotificationTapFromSystem(String? payload) {
    if (payload == null || payload.isEmpty) return;
    Map<String, dynamic> map = {};
    try {
      map = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    // Pull nested data if present
    final nested = (map['data'] is Map) ? (map['data'] as Map) : const {};
    final flat = {
      ...map,
      if (!map.containsKey('doctorId') && nested['doctorId'] != null)
        'doctorId': nested['doctorId'],
      if (!map.containsKey('patientId') && nested['patientId'] != null)
        'patientId': nested['patientId'],
      if (!map.containsKey('senderId') && nested['senderId'] != null)
        'senderId': nested['senderId'],
      if (!map.containsKey('senderName') && nested['senderName'] != null)
        'senderName': nested['senderName'],
      if (!map.containsKey('receiverId') && nested['receiverId'] != null)
        'receiverId': nested['receiverId'],
    };

    final type = flat['type'] as String?;
    if (type == 'chat_message') {
      final navigator = NavigationService.navigator;
      if (navigator == null) return;
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final doctorId = (flat['doctorId'] as String?)?.trim();
      final patientId = (flat['patientId'] as String?)?.trim();
      final senderId = (flat['senderId'] as String?)?.trim();
      final notificationId = (flat['notificationId'] as String?)?.trim();

      if (doctorId != null && patientId != null && currentUid != null) {
        if (currentUid == doctorId) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) =>
                  PatientDetailScreen(patientId: patientId, initialTab: 1),
            ),
          );
          return;
        } else if (currentUid == patientId) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) =>
                  DoctorDetailScreen(doctorId: doctorId, initialTab: 1),
            ),
          );
          return;
        }
      }

      // Fallback: if we only have senderId, push both is unsafe; prefer Patient then Doctor
      if (senderId != null && senderId.isNotEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                PatientDetailScreen(patientId: senderId, initialTab: 1),
          ),
        );
      }

      // Auto mark as read when user taps the system banner
      if (notificationId != null && notificationId.isNotEmpty) {
        app_notif.NotificationService.markAsRead(
          notificationId,
        ).catchError((_) {});
      }
    } else if (type == 'incoming_call') {
      final navigator = NavigationService.navigator;
      if (navigator == null) return;
      final callId = (flat['callId'] as String?) ?? '';
      final channelName = (flat['channelName'] as String?) ?? '';
      final callerName = (flat['callerName'] as String?) ?? 'Người gọi';
      final origin = (flat['origin'] as String?) ?? '';
      if (origin == 'flutter_local') {
        // Immediate join on Flutter-local notification taps
        cancelIncomingCallNotification(callId).catchError((_) {});
        app_notif.NotificationService.deleteIncomingCallNotificationsByCallId(
          callId,
        ).catchError((_) {});
        // Accept then go straight to call screen
        CallService().accept(callId).catchError((_) {});
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                VideoCallScreen(channelName: channelName, callId: callId),
          ),
        );
      } else {
        // Native notification taps (or unknown) go to the incoming screen
        // Cancel notification immediately to stop ringtone/vibration
        cancelIncomingCallNotification(callId).catchError((_) {});

        navigator.push(
          MaterialPageRoute(
            builder: (_) => VideoCallIncomingScreen(
              callId: callId,
              channelName: channelName,
              callerName: callerName,
            ),
          ),
        );
        // Best-effort: remove related incoming_call notifications in Firestore
        app_notif.NotificationService.deleteIncomingCallNotificationsByCallId(
          callId,
        ).catchError((_) {});
      }
    }
  }
}
