import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;
  static const _collection = 'notifications';

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
  }
}
