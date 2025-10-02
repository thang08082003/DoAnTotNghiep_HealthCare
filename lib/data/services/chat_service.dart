import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _conversations = 'conversations';

  String conversationIdFor(String a, String b) {
    // deterministic id for a pair
    return (a.compareTo(b) <= 0) ? '${a}_$b' : '${b}_$a';
  }

  Stream<List<ChatMessage>> watchMessages({
    required String userA,
    required String userB,
  }) {
    final convId = conversationIdFor(userA, userB);
    return _firestore
        .collection(_conversations)
        .doc(convId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChatMessage.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String from,
    required String to,
    required String text,
  }) async {
    final convId = conversationIdFor(from, to);
    final msgRef = _firestore
        .collection(_conversations)
        .doc(convId)
        .collection('messages')
        .doc();
    await msgRef.set({
      'senderId': from,
      'receiverId': to,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> markAsRead({
    required String userA,
    required String userB,
    required String messageId,
  }) async {
    final convId = conversationIdFor(userA, userB);
    await _firestore
        .collection(_conversations)
        .doc(convId)
        .collection('messages')
        .doc(messageId)
        .update({'isRead': true});
  }
}
