import '../services/chat_service.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final ChatService _service;
  ChatRepository({ChatService? service}) : _service = service ?? ChatService();

  Stream<List<ChatMessage>> watchMessages({
    required String userA,
    required String userB,
  }) {
    return _service.watchMessages(userA: userA, userB: userB);
  }

  Future<void> sendMessage({
    required String from,
    required String to,
    required String text,
  }) {
    return _service.sendMessage(from: from, to: to, text: text);
  }

  Future<void> sendImageMessage({
    required String from,
    required String to,
    required List<int> bytes,
    required String fileExt,
  }) {
    return _service.sendImageMessage(
      from: from,
      to: to,
      bytes: bytes,
      fileExt: fileExt,
    );
  }

  Future<void> sendFileMessage({
    required String from,
    required String to,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) {
    return _service.sendFileMessage(
      from: from,
      to: to,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
