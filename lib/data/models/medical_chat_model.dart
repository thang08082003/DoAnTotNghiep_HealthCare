// Model for Medical Chatbot API

enum ChatMode {
  thongtin('thongtin'),
  problem('problem');

  final String value;
  const ChatMode(this.value);

  static ChatMode fromString(String value) {
    return ChatMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChatMode.thongtin,
    );
  }
}

class MedicalChatRequest {
  final String message;
  final ChatMode mode;

  const MedicalChatRequest({required this.message, required this.mode});

  Map<String, dynamic> toJson() {
    return {'message': message, 'mode': mode.value};
  }
}

class MedicalChatResponse {
  final double confidence;
  final String intent;
  final ChatMode mode;
  final String response;

  const MedicalChatResponse({
    required this.confidence,
    required this.intent,
    required this.mode,
    required this.response,
  });

  factory MedicalChatResponse.fromJson(Map<String, dynamic> json) {
    return MedicalChatResponse(
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      intent: json['intent'] as String? ?? '',
      mode: ChatMode.fromString(json['mode'] as String? ?? 'thongtin'),
      response: json['response'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'confidence': confidence,
      'intent': intent,
      'mode': mode.value,
      'response': response,
    };
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final double? confidence;
  final String? intent;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.confidence,
    this.intent,
  });

  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.bot(
    String content, {
    double? confidence,
    String? intent,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      confidence: confidence,
      intent: intent,
    );
  }
}
