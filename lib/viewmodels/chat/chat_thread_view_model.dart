import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';

class ChatThreadViewModel {
  final ChatRepository _repo = ChatRepository();

  Stream<List<ChatMessage>> watchMessages({
    required String userA,
    required String userB,
  }) {
    return _repo.watchMessages(userA: userA, userB: userB);
  }

  Future<void> sendMessage({
    required String from,
    required String to,
    required String text,
  }) {
    return _repo.sendMessage(from: from, to: to, text: text);
  }

  Future<void> sendImageMessage({
    required String from,
    required String to,
    required List<int> bytes,
    required String fileExt,
  }) {
    return _repo.sendImageMessage(
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
    return _repo.sendFileMessage(
      from: from,
      to: to,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  String buildChannelName(String a, String b) {
    return (a.compareTo(b) <= 0) ? '${a}_$b' : '${b}_$a';
  }
}

final chatThreadViewModelProvider = Provider<ChatThreadViewModel>((ref) {
  return ChatThreadViewModel();
});
