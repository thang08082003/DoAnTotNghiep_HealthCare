import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/orders/doctor_orders_view_model.dart';
import 'patient_orders_list_screen.dart';
import '../call/call_waiting_screen.dart';
import '../../viewmodels/call/call_view_model.dart';
import '../../components/info_section/today_health_info_section.dart';
import '../../components/chat/chat_thread_view.dart';
import '../../components/app_bar/chat_app_bar_title.dart';

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
      final raw = await repo.getUserRawById(widget.patientId);
      setState(() {
        _patient = user;
        _raw = raw ?? {};
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: (_tabController.index == 1 && _patient != null)
            ? ChatAppBarTitle(
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: _buildReportsSection(),
              ),

              const SizedBox(height: 16),
              _buildDoctorCreateOrderSection(),

              const SizedBox(height: 16),
            ],
          ),
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

            final ordersVm = ref.read(doctorOrdersViewModelProvider);

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
                                                await ordersVm.createOrder(
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
    return TodayHealthInfoSection(userId: widget.patientId);
  }

  Widget _buildMessagesTab() {
    return ChatThreadView(
      otherUserId: widget.patientId,
      onStartCall: (ctx, currentUserId, otherUserId, channelName) async {
        final callVm = ref.read(callViewModelProvider);
        final callId = await callVm.startOutgoingCall(
          callerId: currentUserId,
          calleeId: otherUserId,
          channelName: channelName,
        );
        if (!ctx.mounted) return;
        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) =>
                CallWaitingScreen(callId: callId, channelName: channelName),
          ),
        );
      },
    );
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
