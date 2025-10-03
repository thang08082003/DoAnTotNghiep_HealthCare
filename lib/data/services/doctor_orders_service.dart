import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_order.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

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

    // Also insert a chat message to notify the patient in the conversation
    final messagesCol = _firestore
        .collection('conversations')
        .doc(convId)
        .collection('messages');
    await messagesCol.add({
      'senderId': doctorId,
      'receiverId': patientId,
      'text': 'Bác sĩ đã tạo chỉ định: $title',
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // Create an app notification so it appears on the Notifications page
    await NotificationService.createNotification(
      toUserId: patientId,
      senderId: doctorId,
      type: NotificationType.doctorFeedback,
      title: 'Chỉ định mới từ bác sĩ',
      body: title,
      data: {
        'doctorId': doctorId,
        'patientId': patientId,
        'conversationId': convId,
        'orderId': doc.id,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }
}
