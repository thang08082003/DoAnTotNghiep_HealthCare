import 'package:flutter/foundation.dart';
import '../../data/models/medical_chat_model.dart';

@immutable
class MedicalChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final ChatMode currentMode;

  const MedicalChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.currentMode = ChatMode.thongtin,
  });

  MedicalChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    ChatMode? currentMode,
  }) {
    return MedicalChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentMode: currentMode ?? this.currentMode,
    );
  }

  // Clear error
  MedicalChatState clearError() {
    return copyWith(error: '');
  }
}
