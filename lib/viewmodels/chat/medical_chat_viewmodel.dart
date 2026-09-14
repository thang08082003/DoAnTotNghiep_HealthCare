import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/medical_chat_model.dart';
import '../../data/repositories/medical_chat_repository.dart';
import 'medical_chat_state.dart';

final medicalChatRepositoryProvider = Provider<MedicalChatRepository>((ref) {
  return MedicalChatRepository();
});

final medicalChatViewModelProvider =
    StateNotifierProvider<MedicalChatViewModel, MedicalChatState>((ref) {
      final repository = ref.watch(medicalChatRepositoryProvider);
      return MedicalChatViewModel(repository);
    });

class MedicalChatViewModel extends StateNotifier<MedicalChatState> {
  final MedicalChatRepository _repository;

  MedicalChatViewModel(this._repository) : super(const MedicalChatState()) {
    _initSession();
    _addWelcomeMessage();
  }

  void _initSession() {
    // Simple session ID generation
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    state = state.copyWith(sessionId: sessionId);
  }

  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage.bot(
      'Xin chào! Tôi là trợ lý y tế AI.\n\n'
      'Tôi có thể giúp bạn tư vấn về sức khỏe, giải đáp thắc mắc về các triệu chứng và bệnh lý.\n\n'
      'Hãy mô tả tình trạng sức khỏe của bạn để tôi có thể hỗ trợ tốt nhất!',
    );

    state = state.copyWith(messages: [welcomeMessage]);
  }

  /// Send a message to the chatbot
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage.user(message.trim());
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    try {
      // Send to API with retry
      final response = await _repository.sendMessageWithRetry(
        message: message.trim(),
        sessionId: state.sessionId,
      );

      // Add bot response - chỉ hiển thị answer
      final botMessage = ChatMessage.bot(
        response.answer,
        confidence: response.confidenceScore,
      );

      state = state.copyWith(
        messages: [...state.messages, botMessage],
        isLoading: false,
      );
    } catch (e) {
      // Add error message
      final errorMessage = ChatMessage.bot(
        '⚠️ Xin lỗi, đã có lỗi xảy ra khi xử lý yêu cầu của bạn. '
        'Vui lòng thử lại sau.\n\nLỗi: ${e.toString()}',
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear all messages and reset
  void clearChat() {
    state = const MedicalChatState();
    _initSession();
    _addWelcomeMessage();
  }

  /// Clear error
  void clearError() {
    state = state.clearError();
  }
}
