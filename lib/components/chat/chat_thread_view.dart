import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/user_provider.dart';
import '../../data/models/chat_message.dart';
import '../../screens/chat/image_preview_screen.dart';
import '../../viewmodels/chat/chat_thread_view_model.dart';

class ChatThreadView extends ConsumerStatefulWidget {
  final String otherUserId;
  final bool showCallButton;
  final Future<void> Function(
    BuildContext context,
    String currentUserId,
    String otherUserId,
    String channelName,
  )?
  onStartCall;

  const ChatThreadView({
    super.key,
    required this.otherUserId,
    this.showCallButton = true,
    this.onStartCall,
  });

  @override
  ConsumerState<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends ConsumerState<ChatThreadView> {
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatInputFocus = FocusNode();
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _chatScrollController.dispose();
    _chatInputFocus.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref.read(currentUserProvider.future),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final currentUser = snap.data!;
        final otherId = widget.otherUserId;
        if (currentUser.uid == otherId) {
          return const Center(child: Text('Không thể chat với chính mình'));
        }

        final vm = ref.read(chatThreadViewModelProvider);
        final stream = vm.watchMessages(userA: currentUser.uid, userB: otherId);

        return Column(
          children: [
            if (widget.showCallButton)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.video_call),
                    label: const Text('Gọi video'),
                    onPressed: widget.onStartCall == null
                        ? null
                        : () async {
                            final channel = vm.buildChannelName(
                              currentUser.uid,
                              otherId,
                            );
                            await widget.onStartCall!.call(
                              context,
                              currentUser.uid,
                              otherId,
                              channel,
                            );
                          },
                  ),
                ),
              ),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: stream,
                builder: (context, ss) {
                  if (!ss.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = ss.data!;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_chatScrollController.hasClients) {
                      _chatScrollController.jumpTo(
                        _chatScrollController.position.maxScrollExtent,
                      );
                    }
                  });
                  return ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final m = messages[index];
                      final mine = m.senderId == currentUser.uid;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: mine ? Colors.blue[50] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _buildMessageContent(context, m),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: () async {
                        await _onAttachPressed(
                          context: context,
                          viewModel: vm,
                          currentUserId: currentUser.uid,
                          otherId: otherId,
                        );
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _chatInputFocus,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = _textController.text.trim();
                        if (text.isEmpty) return;
                        await vm.sendMessage(
                          from: currentUser.uid,
                          to: otherId,
                          text: text,
                        );
                        _textController.clear();
                        _chatInputFocus.unfocus();
                        await Future.delayed(const Duration(milliseconds: 50));
                        if (_chatScrollController.hasClients) {
                          _chatScrollController.animateTo(
                            _chatScrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageContent(BuildContext context, ChatMessage m) {
    if (m.isImage && (m.mediaUrl ?? '').isNotEmpty) {
      final url = m.mediaUrl!;
      return GestureDetector(
        onTap: () async {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ImagePreviewScreen(imageUrl: url),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
            child: Image.network(url, fit: BoxFit.cover),
          ),
        ),
      );
    }
    if (m.isFile && (m.mediaUrl ?? '').isNotEmpty) {
      final url = m.mediaUrl!;
      final name = m.fileName ?? 'Tệp đính kèm';
      return InkWell(
        onTap: () async {
          final mime = (m.mimeType ?? '').toLowerCase();
          final isImageLike = mime.startsWith('image/');
          if (isImageLike) {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImagePreviewScreen(imageUrl: url),
              ),
            );
          } else {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 20),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }
    return Text(m.text);
  }

  Future<void> _onAttachPressed({
    required BuildContext context,
    required ChatThreadViewModel viewModel,
    required String currentUserId,
    required String otherId,
  }) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn ảnh từ thư viện'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picker = ImagePicker();
                  final x = await picker.pickImage(source: ImageSource.gallery);
                  if (x == null) return;
                  final bytes = await x.readAsBytes();
                  final path = x.name.toLowerCase();
                  String ext = 'jpeg';
                  if (path.endsWith('.png')) ext = 'png';
                  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
                    ext = 'jpeg';
                  }
                  await viewModel.sendImageMessage(
                    from: currentUserId,
                    to: otherId,
                    bytes: bytes,
                    fileExt: ext,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Chọn tệp'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final result = await FilePicker.platform.pickFiles(
                    withData: true,
                    allowMultiple: false,
                  );
                  if (result == null || result.files.isEmpty) return;
                  final f = result.files.first;
                  final data = f.bytes;
                  if (data == null) return;
                  String? mime;
                  final ext = (f.extension ?? '').toLowerCase();
                  switch (ext) {
                    case 'png':
                      mime = 'image/png';
                      break;
                    case 'jpg':
                    case 'jpeg':
                      mime = 'image/jpeg';
                      break;
                    case 'gif':
                      mime = 'image/gif';
                      break;
                    case 'webp':
                      mime = 'image/webp';
                      break;
                    default:
                      mime = null;
                  }
                  try {
                    await viewModel.sendFileMessage(
                      from: currentUserId,
                      to: otherId,
                      bytes: data,
                      fileName: f.name,
                      mimeType: mime,
                    );
                  } on UnsupportedError catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message ?? e.toString())),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
