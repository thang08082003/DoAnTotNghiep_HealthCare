import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../router/navigation_service.dart';
import '../../screens/doctors/doctor_detail_screen.dart';
import '../../screens/patients/patient_detail_screen.dart';
import '../../screens/call/video_call_incoming_screen.dart';
import 'notification_service.dart' as app_notif;
import 'call_service.dart';
import '../../screens/call/video_call_screen.dart';

class LocalNotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _firestore = FirebaseFirestore.instance;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'local_high_importance',
        'Local High Importance',
        description: 'Local notifications for app events',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _incomingCallChannel =
      AndroidNotificationChannel(
        'incoming_call_channel',
        'Incoming Calls',
        description: 'Incoming call alerts',
        importance: Importance.max,
      );

  static bool _initialized = false;
  static StreamSubscription? _sub;
  static String? _listeningUserId;
  static final Set<String> _shownIds = <String>{};

  static Future<void> initialize() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (resp) {
        // iOS/Android tap handler for foreground/background
        handleNotificationTapFromSystem(resp.payload);
      },
    );
    // Request notification permission where required
    await _requestPermissions();
    if (!kIsWeb) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_androidChannel);
      await android?.createNotificationChannel(_incomingCallChannel);
    }
    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    // Android 13+
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      // Request runtime notification permission on Android 13+
      final req = await Permission.notification.request();
      if (!req.isGranted) {
        debugPrint('[LocalNotifications] Notification permission not granted');
      }
    }
    // iOS
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Start listening to Firestore notifications for the given user and
  /// show a local notification whenever a new document appears.
  static Future<void> startListeningUserNotifications(String userId) async {
    await initialize();
    // CRITICAL: Stop old listener if userId changed to prevent listening to wrong user
    if (_listeningUserId != null && _listeningUserId != userId) {
      debugPrint(
        '[LocalNotifications] User changed from $_listeningUserId to $userId, stopping old listener',
      );
      await stop();
    }
    if (_listeningUserId == userId && _sub != null) return;
    await stop();
    _listeningUserId = userId;
    _shownIds.clear();
    debugPrint('[LocalNotifications] Start listening for user: $userId');
    _sub = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added &&
                  change.type != DocumentChangeType.modified) {
                continue;
              }
              final data = change.doc.data() ?? {};
              // Skip incoming call notifications on Flutter side; handled by in-app screen or native
              final skipType = (data['type'] as String?) ?? '';
              if (skipType == 'incoming_call') continue;
              final notifId = change.doc.id;
              if (_shownIds.contains(notifId)) continue; // de-dup per session
              final title = (data['title'] as String?) ?? 'Thông báo';
              final body = (data['body'] as String?) ?? '';
              final payload = _encodePayload(data, id: notifId);
              _show(title: title, body: body, payload: payload);
              _shownIds.add(notifId);
              debugPrint(
                '[LocalNotifications] Shown notif=$notifId title="$title"',
              );
            }
          },
          onError: (e, st) {
            debugPrint('[LocalNotifications] Listen error: $e');
          },
        );
  }

  static Future<void> stop() async {
    debugPrint(
      '[LocalNotifications] Stopping listener for user: $_listeningUserId',
    );
    await _sub?.cancel();
    _sub = null;
    _listeningUserId = null;
    _shownIds.clear();
  }

  // lastSeen removed per current strategy (pure realtime while app is active)

  static Future<void> _show({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) {
    return _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(1 << 20),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'local_high_importance',
          'Local High Importance',
          channelDescription: 'Local notifications for app events',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // Public helper to show an incoming call notification (Android/iOS local)
  static Future<void> showIncomingCall({
    required String callId,
    required String channelName,
    required String callerId,
    required String callerName,
  }) async {
    await initialize();
    final notifId = _notificationIdForCall(callId);
    final payload = jsonEncode({
      'type': 'incoming_call',
      'callId': callId,
      'channelName': channelName,
      'callerId': callerId,
      'callerName': callerName,
      'origin': 'flutter_local',
    });
    final androidDetails = AndroidNotificationDetails(
      _incomingCallChannel.id,
      _incomingCallChannel.name,
      channelDescription: _incomingCallChannel.description,
      category: AndroidNotificationCategory.call,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      playSound: true,
      // To use a custom ringtone, add a file at android/app/src/main/res/raw/ringtone.mp3
      // and uncomment the next line:
      // sound: RawResourceAndroidNotificationSound('ringtone'),
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentSound: true),
    );
    await _plugin.show(
      notifId,
      'Cuộc gọi đến',
      'Từ $callerName',
      details,
      payload: payload,
    );
  }

  static int _notificationIdForCall(String callId) {
    // Create a stable positive int id from callId
    final h = callId.hashCode;
    return (h & 0x7fffffff) % 100000000; // keep it within a reasonable range
  }

  static Future<void> cancelIncomingCallNotification(String callId) async {
    final id = _notificationIdForCall(callId);
    await _plugin.cancel(id);
  }

  static String? _encodePayload(Map<String, dynamic> data, {String? id}) {
    // Only include fields that are safe/needed
    try {
      final type = data['type'] as String?;
      final senderId =
          (data['senderId'] as String?) ??
          (data['data'] is Map ? (data['data']['senderId'] as String?) : null);
      final senderName = (data['data'] is Map)
          ? (data['data']['senderName'] as String?)
          : null;
      final doctorId = (data['data'] is Map)
          ? (data['data']['doctorId'] as String?)
          : null;
      final patientId = (data['data'] is Map)
          ? (data['data']['patientId'] as String?)
          : null;
      final receiverId = (data['data'] is Map)
          ? (data['data']['receiverId'] as String?)
          : (data['userId'] as String?);
      final map = <String, dynamic>{
        if (type != null) 'type': type,
        if (senderId != null) 'senderId': senderId,
        if (senderName != null) 'senderName': senderName,
        if (doctorId != null) 'doctorId': doctorId,
        if (patientId != null) 'patientId': patientId,
        if (receiverId != null) 'receiverId': receiverId,
        if (id != null) 'notificationId': id,
      };
      return map.isEmpty ? null : jsonEncode(map);
    } catch (_) {
      return null;
    }
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

  /// Call this at app start after initialization to handle cold start launches
  /// that occurred due to a notification tap.
  static Future<void> handleInitialNotificationLaunch() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final resp = details?.notificationResponse;
      if (details?.didNotificationLaunchApp == true && resp?.payload != null) {
        handleNotificationTapFromSystem(resp!.payload);
      }
    } catch (_) {}
  }
}
