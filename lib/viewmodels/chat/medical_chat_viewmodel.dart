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
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage.bot(
      'Xin chào! Tôi là trợ lý y tế AI. Tôi có thể giúp bạn:\n\n'
      '📚 Tìm hiểu thông tin về bệnh lý\n'
      '🔍 Phân tích triệu chứng\n\n'
      'Bạn có thể chọn chế độ chat và bắt đầu hỏi tôi nhé!',
    );

    state = state.copyWith(messages: [welcomeMessage]);
  }

  /// Change chat mode
  void changeMode(ChatMode mode) {
    if (state.currentMode != mode) {
      state = state.copyWith(currentMode: mode);

      final modeMessage = ChatMessage.bot(
        mode == ChatMode.thongtin
            ? '✅ Đã chuyển sang chế độ "Tìm hiểu thông tin". Bạn có thể hỏi về bệnh lý, triệu chứng, cách điều trị...'
            : '✅ Đã chuyển sang chế độ "Phân tích vấn đề". Hãy mô tả các triệu chứng bạn đang gặp phải.',
      );

      state = state.copyWith(messages: [...state.messages, modeMessage]);
    }
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
        mode: state.currentMode,
      );

      // Add bot response
      final botMessage = ChatMessage.bot(
        response.response,
        confidence: response.confidence,
        intent: response.intent,
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
    _addWelcomeMessage();
  }

  /// Clear error
  void clearError() {
    state = state.clearError();
  }
}
