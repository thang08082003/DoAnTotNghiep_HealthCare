import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/reviews/inline_user_avatar.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../components/chat/chat_thread_view.dart';
import '../../components/app_bar/chat_app_bar_title.dart';
import '../../viewmodels/orders/doctor_orders_view_model.dart';
import '../../data/models/doctor_order.dart';
import '../../viewmodels/reviews/doctor_reviews_view_model.dart';
import '../patients/patient_orders_list_screen.dart';
import '../call/call_waiting_screen.dart';
import '../../viewmodels/call/call_view_model.dart';
import 'dart:async';
import 'doctor_reviews_screen.dart';
import '../../components/reviews/reviews_summary.dart';
import '../../components/reviews/reviews_list.dart';
import '../../components/reviews/review_editor_sheet.dart';
import '../../viewmodels/follow/follow_request_view_model.dart';
import '../profile/edit_doctor_profile_screen.dart';

class DoctorDetailScreen extends ConsumerStatefulWidget {
  final String doctorId;
  final int initialTab; // 0: Thông tin bác sĩ, 1: Tin nhắn
  final bool infoOnly; // when true, show only info tab and hide orders/chat
  const DoctorDetailScreen({
    super.key,
    required this.doctorId,
    this.initialTab = 0,
    this.infoOnly = false,
  });

  @override
  ConsumerState<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  UserModel? _user; // may be DoctorModel
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Debug log
    print(
      'DoctorDetailScreen: infoOnly = ${widget.infoOnly}, doctorId = ${widget.doctorId}',
    );
    _tabController = TabController(
      length: widget.infoOnly ? 1 : 2, // Only 1 tab if infoOnly
      vsync: this,
      initialIndex: widget.infoOnly ? 0 : widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
      if (_tabController.index != 1) {
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
      final user = await repo.getUserById(widget.doctorId);
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi tải thông tin bác sĩ: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabsList = widget.infoOnly
        ? const [Tab(text: 'Thông tin bác sĩ')]
        : const [Tab(text: 'Thông tin bác sĩ'), Tab(text: 'Tin nhắn')];
    print(
      'DoctorDetailScreen.build: infoOnly=${widget.infoOnly}, _tabController.length=${_tabController.length}, tabsList.length=${tabsList.length}',
    );
    return Scaffold(
      appBar: AppBar(
        title: (_tabController.index == 1 && _user != null && !widget.infoOnly)
            ? ChatAppBarTitle(name: _user!.name, avatarUrl: _user!.avatarUrl)
            : const Text('Thông tin bác sĩ'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          tabs: tabsList,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
              children: widget.infoOnly
                  ? [_buildInfoTab()]
                  : [_buildInfoTab(), _buildMessagesTab()],
            ),
    );
  }

  Widget _buildInfoTab({bool infoOnly = false}) {
    final name = _user?.name ?? '';
    final email = _user?.email ?? '';
    final isDoctor = _user is DoctorModel;
    final specialty = isDoctor
        ? ((_user as DoctorModel).specialty.vietnameseName)
        : 'Chưa cập nhật';
    final years = isDoctor
        ? ((_user as DoctorModel).yearsExperience?.toString() ??
              'Chưa cập nhật')
        : 'Chưa cập nhật';
    final description = isDoctor
        ? ((_user as DoctorModel).description == null ||
                  (_user as DoctorModel).description!.isEmpty
              ? 'Chưa có mô tả'
              : (_user as DoctorModel).description!)
        : 'Không áp dụng';
    final avatarUrl = _user?.avatarUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: InlineUserAvatar(
                userId: widget.doctorId,
                initialUrl: avatarUrl,
                displayName: name,
                radius: 40,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('Tên bác sĩ', name),
            _infoRow('Email', email),
            _infoRow('Chuyên khoa', specialty),
            _infoRow('Kinh nghiệm (năm)', years),
            const SizedBox(height: 8),
            _buildDescriptionSection(description, isDoctor),
            const SizedBox(height: 16),
            _buildRatingsSection(),
            const SizedBox(height: 16),
            if (!infoOnly) _buildDoctorOrdersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(String description, bool isDoctor) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final isOwnProfile = (currentUserAsync.asData?.value?.uid == _user?.uid);
    return GestureDetector(
      onTap: (isDoctor && isOwnProfile)
          ? () async {
              // Navigate to edit screen then reload
              final changed = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditDoctorProfileScreen(),
                ),
              );
              if (changed == true) {
                _load();
              }
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.description,
                  size: 18,
                  color: AppColors.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Mô tả',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isDoctor && isOwnProfile) const Spacer(),
                if (isDoctor && isOwnProfile)
                  const Icon(
                    Icons.edit,
                    size: 16,
                    color: AppColors.primaryColor,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: description == 'Chưa có mô tả'
                    ? Colors.grey
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsSection() {
    // Patients can see rating and reviews; doctors can also see but cannot add
    return Consumer(
      builder: (context, ref, _) {
        final reviewsVm = ref.read(doctorReviewsViewModelProvider);
        return FutureBuilder(
          future: ref.read(currentUserProvider.future),
          builder: (context, snap) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReviewsSummary(
                    doctorId: widget.doctorId,
                    reviewsVm: reviewsVm,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DoctorReviewsScreen(
                            doctorId: widget.doctorId,
                            doctorName: _user?.name,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ReviewsList(
                    doctorId: widget.doctorId,
                    reviewsVm: reviewsVm,
                    limit: 5,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void showAddReviewSheet(DoctorReviewsViewModel reviewsVm) {
    ReviewEditorSheet.show(
      context: context,
      doctorId: widget.doctorId,
      reviewsVm: reviewsVm,
    );
  }

  Widget _buildDoctorOrdersSection() {
    // Only show for patient role; otherwise hidden
    return Consumer(
      builder: (context, ref, _) {
        return FutureBuilder(
          future: ref.read(currentUserProvider.future),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox.shrink();
            }
            final currentUser = snap.data!;
            if (!currentUser.isPatient) {
              return const SizedBox.shrink();
            }

            // Hide orders unless follow request status is accepted
            final followVm = ref.read(followRequestViewModelProvider);
            return FutureBuilder<String?>(
              future: followVm.getRequestStatus(
                patientId: currentUser.uid,
                doctorId: widget.doctorId,
              ),
              builder: (context, statusSnap) {
                if (statusSnap.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                final status = (statusSnap.data ?? '').toLowerCase();
                if (status != 'accepted') {
                  return const SizedBox.shrink();
                }

                final ordersVm = ref.read(doctorOrdersViewModelProvider);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chỉ định của bác sĩ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<DoctorOrder>>(
                        stream: ordersVm.watchOrders(
                          patientId: currentUser.uid,
                          doctorId: widget.doctorId,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            );
                          }
                          final orders = snapshot.data ?? const <DoctorOrder>[];
                          if (orders.isEmpty) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(
                                  Icons.assignment_turned_in,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Chưa có chỉ định nào được thêm. Khi bác sĩ đưa ra chỉ định (thuốc, xét nghiệm, chế độ sinh hoạt), nội dung sẽ hiển thị tại đây.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          // Hiển thị tối đa 3 chỉ định gần nhất
                          final preview = orders.take(3).toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: preview.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) =>
                                    _orderTile(preview[i]),
                              ),
                              if (orders.length > 3) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '+${orders.length - 3} chỉ định khác',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.list_alt),
                                  label: const Text('Xem tất cả'),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PatientOrdersListScreen(
                                          patientId: currentUser.uid,
                                          doctorId: widget.doctorId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _orderTile(DoctorOrder order) {
    final created = order.createdAt != null
        ? '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year}'
        : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((order.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.notes!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                if (created.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    created,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    return ChatThreadView(
      otherUserId: widget.doctorId,
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 160,
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
}
