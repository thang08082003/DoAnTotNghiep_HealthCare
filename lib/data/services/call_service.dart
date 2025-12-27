import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call_session.dart';

class CallService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('call_sessions');

  Future<String> createOutgoingCall({
    required String callerId,
    required String calleeId,
    required String channelName,
  }) async {
    final doc = _col.doc();
    await doc.set({
      'callerId': callerId,
      'calleeId': calleeId,
      'channelName': channelName,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<CallSession?> watchCall(String callId) => _col
      .doc(callId)
      .snapshots()
      .map((d) => d.exists ? CallSession.fromDoc(d) : null);

  Future<void> accept(String callId) async {
    await _col.doc(callId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> decline(String callId) async {
    await _col.doc(callId).update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> end(String callId) async {
    await _col.doc(callId).update({
      'status': 'ended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cleanupOld({Duration maxAge = const Duration(hours: 12)}) async {
    final threshold = DateTime.now().subtract(maxAge);
    final qs = await _col
        .where('createdAt', isLessThan: Timestamp.fromDate(threshold))
        .get();
    for (final d in qs.docs) {
      await d.reference.delete();
    }
  }
}
