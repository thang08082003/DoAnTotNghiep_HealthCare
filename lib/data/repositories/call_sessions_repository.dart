import 'package:cloud_firestore/cloud_firestore.dart';

class CallSessionsRepository {
  final FirebaseFirestore _db;
  CallSessionsRepository(this._db);

  Stream<String?> watchStatus(String callId) {
    return _db
        .collection('call_sessions')
        .doc(callId)
        .snapshots()
        .map((d) => d.data()?['status'] as String?);
  }

  Future<void> markEnded(String callId) async {
    await _db.collection('call_sessions').doc(callId).update({
      'status': 'ended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
