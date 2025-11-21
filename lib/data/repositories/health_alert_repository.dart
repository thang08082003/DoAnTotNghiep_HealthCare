import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_alert_model.dart';

class HealthAlertRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a new health alert
  Future<String> saveAlert(HealthAlert alert) async {
    final doc = await _firestore.collection('health_alerts').add(alert.toMap());
    return doc.id;
  }

  /// Get alerts for a specific user
  Stream<List<HealthAlert>> getAlertsStream(String userId, {int limit = 10}) {
    return _firestore
        .collection('health_alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HealthAlert.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get latest alert for a user
  Future<HealthAlert?> getLatestAlert(String userId) async {
    final snapshot = await _firestore
        .collection('health_alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return HealthAlert.fromFirestore(snapshot.docs.first);
  }

  /// Get unread alerts count
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _firestore
        .collection('health_alerts')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  /// Mark alert as read
  Future<void> markAsRead(String alertId) async {
    await _firestore.collection('health_alerts').doc(alertId).update({
      'isRead': true,
    });
  }

  /// Mark all alerts as read for a user
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('health_alerts')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  /// Mark doctor as notified
  Future<void> markDoctorNotified(String alertId) async {
    await _firestore.collection('health_alerts').doc(alertId).update({
      'isDoctorNotified': true,
    });
  }

  /// Delete a specific alert
  Future<void> deleteAlert(String alertId) async {
    await _firestore.collection('health_alerts').doc(alertId).delete();
  }

  /// Delete old alerts (older than specified days)
  Future<void> deleteOldAlerts(String userId, int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    final snapshot = await _firestore
        .collection('health_alerts')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Get alerts by level
  Stream<List<HealthAlert>> getAlertsByLevel(
    String userId,
    AlertLevel level, {
    int limit = 10,
  }) {
    return _firestore
        .collection('health_alerts')
        .where('userId', isEqualTo: userId)
        .where('level', isEqualTo: level.name)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HealthAlert.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get recent abnormal alerts for doctor's patients (warning + danger only)
  /// Returns alerts from the last 24 hours
  Future<List<HealthAlert>> getRecentAbnormalAlertsForPatients(
    List<String> patientIds, {
    int hoursBack = 24,
    int limit = 10,
  }) async {
    if (patientIds.isEmpty) return [];

    final cutoffTime = DateTime.now().subtract(Duration(hours: hoursBack));

    // Firestore 'in' query supports max 10 items
    final batchSize = 10;
    final allAlerts = <HealthAlert>[];

    for (var i = 0; i < patientIds.length; i += batchSize) {
      final batch = patientIds.skip(i).take(batchSize).toList();

      final snapshot = await _firestore
          .collection('health_alerts')
          .where('userId', whereIn: batch)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final alerts = snapshot.docs
          .map((doc) => HealthAlert.fromFirestore(doc))
          .where(
            (alert) =>
                alert.level == AlertLevel.warning ||
                alert.level == AlertLevel.danger,
          )
          .toList();

      allAlerts.addAll(alerts);
    }

    // Sort all alerts by timestamp and take top N
    allAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allAlerts.take(limit).toList();
  }
}
