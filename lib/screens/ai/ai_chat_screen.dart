import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _ctl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _messages = <_Msg>[
    const _Msg(
      sender: _Sender.ai,
      text:
          'Xin chào! Tôi là trợ lý AI. Tôi có thể giúp gì cho bác sĩ hôm nay?',
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _messages.add(_Msg(sender: _Sender.user, text: text));
      _ctl.clear();
    });
    await Future.delayed(const Duration(milliseconds: 100));
    _scrollToEnd();
    // Demo AI response (placeholder)
    await Future.delayed(const Duration(milliseconds: 600));
    final reply = _fakeAiReply(text);
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg(sender: _Sender.ai, text: reply));
      _sending = false;
    });
    await Future.delayed(const Duration(milliseconds: 100));
    _scrollToEnd();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _fakeAiReply(String input) {
    if (input.toLowerCase().contains('xin chào') ||
        input.toLowerCase().contains('chào')) {
      return 'Chào bác sĩ! Bác sĩ cần hỗ trợ về chẩn đoán, thuốc hay quy trình theo dõi?';
    }
    if (input.endsWith('?')) {
      return 'Đây là gợi ý ban đầu dựa trên câu hỏi của bác sĩ. Vui lòng cung cấp thêm dữ liệu lâm sàng để tôi hỗ trợ tốt hơn.';
    }
    return 'Tôi đã ghi nhận. Bác sĩ có thể đặt câu hỏi cụ thể hơn để tôi phân tích chi tiết.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat với AI'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m.sender == _Sender.user;
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.primaryColor
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Nhập câu hỏi cho AI...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    label: const Text('Gửi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Sender { user, ai }

class _Msg {
  final _Sender sender;
  final String text;
  const _Msg({required this.sender, required this.text});
}
