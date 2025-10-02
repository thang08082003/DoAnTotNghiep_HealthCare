import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

/// Service to manage follow requests between patients and doctors.
/// A follow request lets a patient request a doctor to follow/monitor them.
///
/// Firestore collection: follow_requests
/// Document ID convention: `patientId_doctorId`
/// Document schema:
/// {
///   patientId: string,
///   doctorId: string,
///   status: 'pending' | 'accepted' | 'rejected' | 'cancelled',
///   createdAt: Timestamp,
///   updatedAt: Timestamp
/// }
class FollowRequestService {
  static final _firestore = FirebaseFirestore.instance;
  static const _collection = 'follow_requests';
  static const _usersCollection = 'users';

  static String _docId(String patientId, String doctorId) =>
      '${patientId}_$doctorId';

  /// Create a follow request. Returns true if created or already pending/accepted.
  static Future<bool> requestFollow({
    required String patientId,
    required String doctorId,
    String? patientName,
  }) async {
    final docRef = _firestore
        .collection(_collection)
        .doc(_docId(patientId, doctorId));
    final createdOrPending = await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      final now = FieldValue.serverTimestamp();

      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final status = (data['status'] as String?) ?? 'pending';
        // If already pending or accepted, treat as success (no-op)
        if (status == 'pending' || status == 'accepted') return true;
        // If previously rejected/cancelled, re-open as pending
        txn.update(docRef, {'status': 'pending', 'updatedAt': now});
        return true;
      } else {
        txn.set(docRef, {
          'patientId': patientId,
          'doctorId': doctorId,
          'status': 'pending',
          'createdAt': now,
          'updatedAt': now,
        });
        return true;
      }
    });
    // Fire-and-forget: notify doctor about new follow request
    if (createdOrPending) {
      try {
        // Determine patient name
        String nameToUse = (patientName ?? '').trim();
        if (nameToUse.isEmpty) {
          try {
            final userDoc = await _firestore
                .collection(_usersCollection)
                .doc(patientId)
                .get();
            final data = userDoc.data();
            if (data != null && data['name'] is String) {
              nameToUse = (data['name'] as String).trim();
            }
          } catch (_) {}
          if (nameToUse.isEmpty) nameToUse = 'bệnh nhân';
        }

        await NotificationService.createNotification(
          toUserId: doctorId,
          senderId: patientId,
          type: NotificationType.followRequest,
          title: 'Yêu cầu theo dõi từ $nameToUse',
          body: 'Bệnh nhân $nameToUse đã gửi yêu cầu theo dõi.',
          data: {
            'requestId': _docId(patientId, doctorId),
            'patientId': patientId,
            'doctorId': doctorId,
            'patientName': nameToUse,
          },
        );
      } catch (_) {}
    }
    return true;
  }

  /// Get the request status between a patient and a doctor. Returns null if not exists.
  static Future<String?> getRequestStatus({
    required String patientId,
    required String doctorId,
  }) async {
    final doc = await _firestore
        .collection(_collection)
        .doc(_docId(patientId, doctorId))
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    return data != null ? data['status'] as String? : null;
  }

  /// Get all follow requests for a patient, keyed by doctorId -> status.
  static Future<Map<String, String>> getRequestsForPatient(
    String patientId,
  ) async {
    final query = await _firestore
        .collection(_collection)
        .where('patientId', isEqualTo: patientId)
        .get();
    final map = <String, String>{};
    for (final doc in query.docs) {
      final data = doc.data();
      final doctorId = data['doctorId'] as String?;
      final status = data['status'] as String?;
      if (doctorId != null && status != null) {
        map[doctorId] = status;
      }
    }
    return map;
  }

  /// Get patient IDs that a doctor is currently following (status == 'accepted').
  static Future<List<String>> getAcceptedPatientIdsForDoctor(
    String doctorId,
  ) async {
    final query = await _firestore
        .collection(_collection)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'accepted')
        .get();
    return query.docs
        .map((d) => (d.data()['patientId'] as String?))
        .whereType<String>()
        .toList();
  }

  /// Get doctor IDs that a patient is currently following (status == 'accepted').
  static Future<List<String>> getAcceptedDoctorIdsForPatient(
    String patientId,
  ) async {
    final query = await _firestore
        .collection(_collection)
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'accepted')
        .get();
    return query.docs
        .map((d) => (d.data()['doctorId'] as String?))
        .whereType<String>()
        .toList();
  }

  /// Accept a follow request and notify the patient.
  static Future<void> acceptRequest({
    required String requestId,
    required String doctorId,
    required String patientId,
    String? doctorName,
  }) async {
    await _firestore.collection(_collection).doc(requestId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      // Determine doctor name
      String nameToUse = (doctorName ?? '').trim();
      if (nameToUse.isEmpty) {
        try {
          final userDoc = await _firestore
              .collection(_usersCollection)
              .doc(doctorId)
              .get();
          final data = userDoc.data();
          if (data != null && data['name'] is String) {
            nameToUse = (data['name'] as String).trim();
          }
        } catch (_) {}
        if (nameToUse.isEmpty) nameToUse = 'bác sĩ';
      }

      await NotificationService.createNotification(
        toUserId: patientId,
        senderId: doctorId,
        type: NotificationType.doctorFeedback,
        title: 'Bác sĩ $nameToUse đã chấp nhận',
        body: 'Bác sĩ $nameToUse đã chấp nhận yêu cầu theo dõi của bạn.',
        data: {
          'requestId': requestId,
          'patientId': patientId,
          'doctorId': doctorId,
          'status': 'accepted',
          'doctorName': nameToUse,
        },
      );
    } catch (_) {}
  }

  /// Decline a follow request and notify the patient.
  static Future<void> declineRequest({
    required String requestId,
    required String doctorId,
    required String patientId,
    String? doctorName,
  }) async {
    await _firestore.collection(_collection).doc(requestId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      // Determine doctor name
      String nameToUse = (doctorName ?? '').trim();
      if (nameToUse.isEmpty) {
        try {
          final userDoc = await _firestore
              .collection(_usersCollection)
              .doc(doctorId)
              .get();
          final data = userDoc.data();
          if (data != null && data['name'] is String) {
            nameToUse = (data['name'] as String).trim();
          }
        } catch (_) {}
        if (nameToUse.isEmpty) nameToUse = 'bác sĩ';
      }

      await NotificationService.createNotification(
        toUserId: patientId,
        senderId: doctorId,
        type: NotificationType.doctorFeedback,
        title: 'Bác sĩ $nameToUse đã từ chối',
        body: 'Bác sĩ $nameToUse đã từ chối yêu cầu theo dõi của bạn.',
        data: {
          'requestId': requestId,
          'patientId': patientId,
          'doctorId': doctorId,
          'status': 'rejected',
          'doctorName': nameToUse,
        },
      );
    } catch (_) {}
  }
}
