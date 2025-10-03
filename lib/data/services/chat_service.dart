import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../services/media_upload_service.dart';

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

  Future<void> sendImageMessage({
    required String from,
    required String to,
    required List<int> bytes,
    String fileExt = 'jpeg',
  }) async {
    final convId = conversationIdFor(from, to);
    // Upload image via configured provider (Cloudinary by default)
    final url = await MediaUploadService.uploadAvatar(
      uid: from,
      data: Uint8List.fromList(bytes),
      fileExt: fileExt,
    );
    final msgRef = _firestore
        .collection(_conversations)
        .doc(convId)
        .collection('messages')
        .doc();
    await msgRef.set({
      'senderId': from,
      'receiverId': to,
      'text': '',
      'type': 'image',
      'mediaUrl': url,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> sendFileMessage({
    required String from,
    required String to,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    // For simplicity, reuse Cloudinary for images; for arbitrary files you may
    // plug another provider (e.g., Supabase Storage) in MediaUploadService.
    // Here we'll upload as image if mimeType starts with image/ else throw.
    if (mimeType == null || !mimeType.startsWith('image/')) {
      throw UnsupportedError(
        'Chỉ hỗ trợ gửi file hình ảnh trong phiên bản này',
      );
    }
    final ext = fileName.split('.').last.toLowerCase();
    await sendImageMessage(
      from: from,
      to: to,
      bytes: bytes,
      fileExt: ext == 'jpg' ? 'jpeg' : ext,
    );
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
