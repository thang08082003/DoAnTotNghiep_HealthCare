import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/medical_chat_model.dart';

class MedicalChatRepository {
  static const String _baseUrl = 'https://tungdk-medbot.hf.space/api/chat';

  static const Duration _timeout = Duration(seconds: 30);

  /// Send a message to the medical chatbot API
  Future<MedicalChatResponse> sendMessage({
    required String message,
    required ChatMode mode,
  }) async {
    try {
      final request = MedicalChatRequest(message: message, mode: mode);

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return MedicalChatResponse.fromJson(json);
      } else {
        throw Exception(
          'Failed to get response: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  /// Send message with automatic retry on failure
  Future<MedicalChatResponse> sendMessageWithRetry({
    required String message,
    required ChatMode mode,
    int maxRetries = 2,
  }) async {
    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        return await sendMessage(message: message, mode: mode);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempts++;
        if (attempts < maxRetries) {
          // Wait before retry (exponential backoff)
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
    }

    throw lastError ?? Exception('Failed after $maxRetries attempts');
  }
}
