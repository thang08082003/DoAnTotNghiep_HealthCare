import 'package:cloud_firestore/cloud_firestore.dart';

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

  static String _docId(String patientId, String doctorId) =>
      '${patientId}_$doctorId';

  /// Create a follow request. Returns true if created or already pending/accepted.
  static Future<bool> requestFollow({
    required String patientId,
    required String doctorId,
  }) async {
    final docRef = _firestore
        .collection(_collection)
        .doc(_docId(patientId, doctorId));
    return _firestore.runTransaction((txn) async {
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
}
