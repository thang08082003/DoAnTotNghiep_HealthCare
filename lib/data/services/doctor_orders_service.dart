import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_order.dart';

class DoctorOrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _convId(String a, String b) =>
      (a.compareTo(b) <= 0) ? '${a}_$b' : '${b}_$a';

  Stream<List<DoctorOrder>> watchOrders({
    required String patientId,
    required String doctorId,
  }) {
    final convId = _convId(patientId, doctorId);
    return _firestore
        .collection('conversations')
        .doc(convId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => DoctorOrder.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> createOrder({
    required String patientId,
    required String doctorId,
    required String title,
    String? notes,
  }) async {
    final convId = _convId(patientId, doctorId);
    final doc = _firestore
        .collection('conversations')
        .doc(convId)
        .collection('orders')
        .doc();
    await doc.set({
      'doctorId': doctorId,
      'patientId': patientId,
      'title': title,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
