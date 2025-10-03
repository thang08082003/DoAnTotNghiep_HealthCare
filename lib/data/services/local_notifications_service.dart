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
    _sub = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() ?? {};
              final title = (data['title'] as String?) ?? 'Thông báo';
              final body = (data['body'] as String?) ?? '';
              final payload = _encodePayload(data);
              _show(title: title, body: body, payload: payload);
            }
          }
        });
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _listeningUserId = null;
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

  static String? _encodePayload(Map<String, dynamic> data) {
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
