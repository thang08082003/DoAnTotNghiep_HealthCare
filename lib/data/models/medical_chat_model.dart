// Model for Medical Chatbot API

class MedicalChatRequest {
  final String message;
  final String? sessionId;
  final bool debug;

  const MedicalChatRequest({
    required this.message,
    this.sessionId,
    this.debug = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      if (sessionId != null) 'session_id': sessionId,
      'debug': debug,
    };
  }
}

class MedicalChatResponse {
  final String answer;
  final String? confidence; // "high", "medium", "low"
  final List<Map<String, String>>? citations;
  final List<String>? followupQuestions;
  final List<String>? possibleConditions;
  final String? disclaimer;

  const MedicalChatResponse({
    required this.answer,
    this.confidence,
    this.citations,
    this.followupQuestions,
    this.possibleConditions,
    this.disclaimer,
  });

  factory MedicalChatResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Invalid response format: missing data field');
    }

    return MedicalChatResponse(
      answer: data['answer'] as String? ?? '',
      confidence: data['confidence'] as String?,
      citations: (data['citations'] as List<dynamic>?)
          ?.map((e) => Map<String, String>.from(e as Map))
          .toList(),
      followupQuestions: (data['followup_questions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      possibleConditions: (data['possible_conditions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      disclaimer: data['disclaimer'] as String?,
    );
  }

  // Convert confidence string to number for UI
  double? get confidenceScore {
    switch (confidence?.toLowerCase()) {
      case 'high':
        return 0.9;
      case 'medium':
        return 0.7;
      case 'low':
        return 0.5;
      default:
        return null;
    }
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
