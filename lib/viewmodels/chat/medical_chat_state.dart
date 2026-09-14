import 'package:flutter/foundation.dart';
import '../../data/models/medical_chat_model.dart';

@immutable
class MedicalChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final String? sessionId;

  const MedicalChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.sessionId,
  });

  MedicalChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    String? sessionId,
  }) {
    return MedicalChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  // Clear error
  MedicalChatState clearError() {
    return copyWith(error: '');
  }
}
