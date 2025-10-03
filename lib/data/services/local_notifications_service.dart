import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import '../../router/navigation_service.dart';
import '../../screens/doctors/doctor_detail_screen.dart';
import '../../screens/patients/patient_detail_screen.dart';

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

  static bool _initialized = false;
  static StreamSubscription? _sub;
  static String? _listeningUserId;
  static const String _prefsKeyPrefix = 'notifications_last_seen_';

  static Future<void> initialize() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (resp) {
        // iOS/Android tap handler for foreground/background
        _handleNotificationTap(resp.payload);
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
    }
    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    // Android 13+
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
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
    if (_listeningUserId == userId && _sub != null) return;
    await stop();
    _listeningUserId = userId;
    DateTime lastSeen = await _getLastSeen(userId);
    bool isFirstSnapshot = true;
    _sub = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) {
          // Avoid blasting historical notifications on login/restart
          if (isFirstSnapshot) {
            isFirstSnapshot = false;
            return;
          }
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() ?? {};
              final notifId = change.doc.id;
              final title = (data['title'] as String?) ?? 'Thông báo';
              final body = (data['body'] as String?) ?? '';
              final created = data['createdAt'];
              DateTime? createdAt;
              if (created is Timestamp) {
                createdAt = created.toDate();
              } else if (created is String) {
                createdAt = DateTime.tryParse(created);
              }
              // Gate by lastSeen if available
              if (createdAt != null && !createdAt.isAfter(lastSeen)) {
                continue;
              }
              final payload = _encodePayload(data, id: notifId);
              _show(title: title, body: body, payload: payload);
              if (createdAt != null && createdAt.isAfter(lastSeen)) {
                lastSeen = createdAt;
                _setLastSeen(userId, lastSeen);
              }
            }
          }
        });
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _listeningUserId = null;
  }

  static Future<DateTime> _getLastSeen(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt('$_prefsKeyPrefix$userId');
      if (ms != null && ms > 0) {
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Future<void> _setLastSeen(String userId, DateTime dt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefsKeyPrefix$userId', dt.millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<void> _show({
    required String title,
    required String body,
    String? payload,
  }) {
    return _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 20),
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

  static void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    Map<String, dynamic> map = {};
    try {
      map = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = map['type'] as String?;
    if (type == 'chat_message') {
      final navigator = NavigationService.navigator;
      if (navigator == null) return;
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final doctorId = (map['doctorId'] as String?)?.trim();
      final patientId = (map['patientId'] as String?)?.trim();
      final senderId = (map['senderId'] as String?)?.trim();
      final notificationId = (map['notificationId'] as String?)?.trim();

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
        NotificationService.markAsRead(notificationId).catchError((_) {});
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
        _handleNotificationTap(resp!.payload);
      }
    } catch (_) {}
  }
}
