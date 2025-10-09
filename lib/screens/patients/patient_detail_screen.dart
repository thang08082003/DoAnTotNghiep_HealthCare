import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../data/services/chat_service.dart';
import '../../data/models/chat_message.dart';
import '../../data/services/doctor_orders_service.dart';
import 'patient_orders_list_screen.dart';
import '../call/video_call_screen.dart';
import '../../data/services/call_service.dart';
import '../../data/models/call_session.dart';
// import '../call/incoming_call_sheet.dart'; // reserved for future incoming overlay
import 'dart:async';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final String patientId;
  final int initialTab; // 0: Thông tin, 1: Tin nhắn
  const PatientDetailScreen({
    super.key,
    required this.patientId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  UserModel? _patient;
  Map<String, dynamic> _raw = const {};
  late final TabController _tabController;
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatInputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
      if (_tabController.index != 1) {
        // rời tab chat thì đóng bàn phím
        FocusScope.of(context).unfocus();
      }
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      final user = await repo.getUserById(widget.patientId);
      DocumentSnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(widget.patientId)
          .get();
      setState(() {
        _patient = user;
        _raw = snap.data() ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi tải thông tin bệnh nhân: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    _chatInputFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: (_tabController.index == 1 && _patient != null)
            ? _PatientChatAppBarTitle(
                name: _patient!.name,
                avatarUrl:
                    _patient!.avatarUrl ?? (_raw['avatarUrl'] as String?),
              )
            : const Text('Thông tin bệnh nhân'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          tabs: const [
            Tab(text: 'Thông tin'),
            Tab(text: 'Tin nhắn'),
          ],
        ),
      ),
      body: _loading
          ? const LoadingWidget()
          : (_error != null)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildInfoTab(), _buildMessagesTab()],
            ),
    );
  }

  Widget _buildInfoTab() {
    final name = _patient?.name ?? (_raw['name'] as String? ?? '');
    final email = _patient?.email ?? (_raw['email'] as String? ?? '');
    final phone = (_raw['phone'] as String?) ?? 'Chưa cập nhật';
    final gender = (_raw['gender'] as String?) ?? 'Chưa cập nhật';
    final age = (_raw['age'] is int)
        ? _raw['age'].toString()
        : ((_raw['age'] as String?) ?? 'Chưa cập nhật');
    final diseaseFocus =
        _patient?.diseaseFocusEnum?.displayName ?? 'Chưa cập nhật';
    final medicalHistory = _formatMedicalHistory(_raw['medicalHistory']);
    final avatarUrl = _patient?.avatarUrl ?? (_raw['avatarUrl'] as String?);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoCard(
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryColor.withValues(
                    alpha: 0.1,
                  ),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.primaryColor,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              _infoRow('Tên', name),
              _infoRow('Số điện thoại', phone),
              _infoRow('Email', email),
              _infoRow('Tuổi', age),
              _infoRow('Giới tính', gender),
              _infoRow('Tiền sử bệnh', medicalHistory),
              _infoRow('Bệnh theo dõi', diseaseFocus),
            ],
          ),
          const SizedBox(height: 16),
          _buildDoctorCreateOrderSection(),
          const SizedBox(height: 16),
          _buildReportsSection(),
        ],
      ),
    );
  }

  Widget _buildDoctorCreateOrderSection() {
    // Only doctors see this section
    return Consumer(
      builder: (context, ref, _) {
        return FutureBuilder(
          future: ref.read(currentUserProvider.future),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final currentUser = snap.data!;
            if (!currentUser.isDoctor) return const SizedBox.shrink();

            final service = DoctorOrdersService();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chỉ định',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_task),
                          label: const Text('Tạo chỉ định'),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              builder: (ctx) {
                                final titleController = TextEditingController();
                                final notesController = TextEditingController();
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(
                                      ctx,
                                    ).viewInsets.bottom,
                                  ),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tạo chỉ định',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: titleController,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Tiêu đề (Thuốc / Xét nghiệm / Chế độ …)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: notesController,
                                          maxLines: 4,
                                          decoration: const InputDecoration(
                                            labelText: 'Ghi chú (tuỳ chọn)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final title = titleController.text
                                                  .trim();
                                              final notes = notesController.text
                                                  .trim();
                                              if (title.isEmpty) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Vui lòng nhập tiêu đề chỉ định',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              try {
                                                await service.createOrder(
                                                  patientId: widget.patientId,
                                                  doctorId: currentUser.uid,
                                                  title: title,
                                                  notes: notes.isEmpty
                                                      ? null
                                                      : notes,
                                                );
                                                if (!mounted) return;
                                                Navigator.of(ctx).pop();
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Đã tạo chỉ định',
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Tạo chỉ định thất bại: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Text('Lưu'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Xem tất cả'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PatientOrdersListScreen(
                                patientId: widget.patientId,
                                doctorId: currentUser.uid,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReportsSection() {
    // Placeholder reports content shown under the information section
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Báo cáo',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Icon(Icons.bar_chart, size: 48, color: AppColors.textSecondary),
                SizedBox(height: 8),
                Text(
                  'Chưa có báo cáo',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    return Consumer(
      builder: (context, ref, _) {
        return FutureBuilder(
          future: ref.read(currentUserProvider.future),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final currentUser = snap.data!;
            final otherId = widget.patientId; // chatting with patient
            final isSelf = currentUser.uid == otherId;
            if (isSelf) {
              return const Center(child: Text('Không thể chat với chính mình'));
            }

            final chatService = ChatService();
            final stream = chatService.watchMessages(
              userA: currentUser.uid,
              userB: otherId,
            );
            final controller = TextEditingController();

            return Column(
              children: [
                // Call button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.video_call),
                      label: const Text('Gọi video'),
                      onPressed: () async {
                        final channel = _buildChannelName(
                          currentUser.uid,
                          otherId,
                        );
                        final callService = CallService();
                        final callId = await callService.createOutgoingCall(
                          callerId: currentUser.uid,
                          calleeId: otherId,
                          channelName: channel,
                        );
                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              const Center(child: CircularProgressIndicator()),
                        );
                        late final StreamSubscription sub;
                        sub = callService.watchCall(callId).listen((
                          session,
                        ) async {
                          if (session == null) return;
                          if (!context.mounted) return;
                          if (session.status == CallStatus.accepted) {
                            Navigator.of(context).pop();
                            sub.cancel();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VideoCallScreen(
                                  channelName: channel,
                                  callId: callId,
                                ),
                              ),
                            );
                          } else if (session.status == CallStatus.declined ||
                              session.status == CallStatus.ended) {
                            Navigator.of(context).pop();
                            sub.cancel();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cuộc gọi không được kết nối'),
                              ),
                            );
                          }
                        });
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
                      // Scroll to bottom after frame
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
                                color: mine
                                    ? Colors.blue[50]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _buildMessageContent(m),
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
                              chatService: chatService,
                              currentUserId: currentUser.uid,
                              otherId: otherId,
                            );
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
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
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            await chatService.sendMessage(
                              from: currentUser.uid,
                              to: otherId,
                              text: text,
                            );
                            controller.clear();
                            _chatInputFocus.unfocus();
                            // ensure scroll bottom after send
                            await Future.delayed(
                              const Duration(milliseconds: 50),
                            );
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
      },
    );
  }

  Widget _buildMessageContent(ChatMessage m) {
    if (m.isImage && (m.mediaUrl ?? '').isNotEmpty) {
      final url = m.mediaUrl!;
      return GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
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
          final uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    required ChatService chatService,
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
                  await chatService.sendImageMessage(
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
                  // Derive mime only for common image types supported for now
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
                    await chatService.sendFileMessage(
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

  String _buildChannelName(String a, String b) {
    return (a.compareTo(b) <= 0) ? '${a}_$b' : '${b}_$a';
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? 'Chưa cập nhật' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMedicalHistory(dynamic raw) {
    if (raw == null) return 'Chưa cập nhật';
    if (raw is String) return raw.isEmpty ? 'Chưa cập nhật' : raw;
    if (raw is List) {
      final texts = raw
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      return texts.isEmpty ? 'Chưa cập nhật' : texts.join(', ');
    }
    return 'Chưa cập nhật';
  }
}

class _PatientChatAppBarTitle extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const _PatientChatAppBarTitle({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
          backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
          child: !hasAvatar
              ? const Icon(
                  Icons.person,
                  size: 16,
                  color: AppColors.primaryColor,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
