import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;
  static const _collection = 'notifications';

  // Use a singleton instance that will be initialized in main.dart
  static FlutterLocalNotificationsPlugin? _localNotifications;

  /// Initialize the notification plugin (call this from main.dart)
  static void initialize(FlutterLocalNotificationsPlugin plugin) {
    _localNotifications = plugin;
  }

  static Stream<List<AppNotification>> watchUserNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(
                (d) => AppNotification.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  static Future<List<AppNotification>> getUserNotifications(
    String userId,
  ) async {
    final query = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .get();
    final list = query.docs
        .map(
          (d) => AppNotification.fromDoc(
            d as DocumentSnapshot<Map<String, dynamic>>,
          ),
        )
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).delete();
  }

  /// Delete all notifications of type 'incoming_call' associated with a callId.
  static Future<void> deleteIncomingCallNotificationsByCallId(
    String callId,
  ) async {
    try {
      final q = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: 'incoming_call')
          .where('data.callId', isEqualTo: callId)
          .get();
      final batch = _firestore.batch();
      for (final d in q.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (_) {
      // ignore best-effort cleanup
    }
  }

  /// Mark notification as read then delete it from Firestore.
  /// Even though the document will be removed, we first set `isRead=true`
  /// to satisfy logic requirements (e.g., analytics or security rules that
  /// may check state transitions) before deletion.
  static Future<void> markReadAndDelete(String notificationId) async {
    final docRef = _firestore.collection(_collection).doc(notificationId);
    try {
      // Best-effort update; ignore if already gone.
      await docRef.update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore update errors (e.g. document missing) and proceed to delete.
    }
    try {
      await docRef.delete();
    } catch (_) {
      // Swallow; caller can decide if they need error handling elsewhere.
    }
  }

  static Future<void> createNotification({
    required String toUserId,
    required String senderId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _firestore.collection(_collection).add({
      'userId': toUserId,
      'senderId': senderId,
      'type': type.value,
      'title': title,
      'body': body,
      'data': data ?? {},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Only show local notification popup if current user is the receiver
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null && currentUserId == toUserId) {
        await _showLocalNotification(
          type: type,
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (_) {
      // Ignore errors in local notification
    }
  }

  /// Show local notification popup
  static Future<void> _showLocalNotification({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Check if plugin is initialized
    if (_localNotifications == null) {
      print('⚠️ NotificationService: Plugin not initialized!');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'healthcare_channel',
      'Healthcare Notifications',
      channelDescription: 'Notifications from Healthcare app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Generate unique notification ID based on type and timestamp
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      print('📲 Showing notification: $title');
      await _localNotifications!.show(notificationId, title, body, details);
      print('✅ Notification shown successfully');
    } catch (e) {
      print('❌ Error showing notification: $e');
      rethrow;
    }
  }
}
