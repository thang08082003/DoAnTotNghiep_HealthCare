import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../components/reviews/inline_user_avatar.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../call/call_waiting_screen.dart';
import '../../viewmodels/call/call_view_model.dart';
import '../../components/info_section/today_health_info_section.dart';
import '../../components/chat/chat_thread_view.dart';
import '../../components/app_bar/chat_app_bar_title.dart';

import 'widgets/patient_medications_tab.dart';

import 'widgets/create_options_bottom_sheet.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final String patientId;
  final int initialTab; // 0: Thông tin, 1: Tin nhắn
  final bool isPending; // true = pending request, hide health info

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    this.initialTab = 0,
    this.isPending = false,
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
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
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
        title: (_tabController.index == 4 && _patient != null)
            ? ChatAppBarTitle(
                name: _patient!.name,
                avatarUrl:
                    _patient!.avatarUrl ?? (_raw['avatarUrl'] as String?),
              )
            : const Text('Thông tin bệnh nhân'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          tabs: const [
            Tab(text: 'Thông tin'),
            Tab(text: 'Thuốc'),
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
              children: [
                _buildInfoTab(),

                PatientMedicationsTab(
                  patientId: widget.patientId,
                  isPending: widget.isPending,
                ),

                _buildMessagesTab(),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    // Only show FAB when on Info tab and not in pending state
    if (_tabController.index != 0 || widget.isPending) {
      return null;
    }

    return FloatingActionButton(
      onPressed: _showCreateOptionsBottomSheet,
      backgroundColor: AppColors.primaryColor,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showCreateOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CreateOptionsBottomSheet(
        patientId: widget.patientId,
        onCreateCarePlan: _createCarePlan,
      ),
    );
  }

  void _createCarePlan() {
    // TODO: Navigate to care plan creation screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tạo kế hoạch chăm sóc - Chức năng đang phát triển'),
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
                child: InlineUserAvatar(
                  userId: widget.patientId,
                  initialUrl: avatarUrl,
                  displayName: name,
                  radius: 40,
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
              _buildAllergicMedicationsSection(),
              const SizedBox(height: 16),

              // Hide health info for pending requests
              if (!widget.isPending) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: _buildReportsSection(),
                ),
                const SizedBox(height: 16),
              ],

              // Show pending message if this is a pending request
              if (widget.isPending)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Thông tin sức khỏe sẽ hiển thị sau khi bạn chấp nhận yêu cầu theo dõi.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
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

  Widget _buildAllergicMedicationsSection() {
    final allergicMeds = _raw['allergicMedications'];
    List<String> medications = [];

    if (allergicMeds is List) {
      medications = allergicMeds
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Thuốc dị ứng',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (medications.isEmpty)
            const Text(
              'Chưa cập nhật',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: medications.map((med) {
                return Chip(
                  label: Text(med),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                  labelStyle: const TextStyle(fontSize: 12),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
