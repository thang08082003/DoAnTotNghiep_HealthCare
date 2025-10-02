import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../data/services/chat_service.dart';
import '../../data/models/chat_message.dart';
import '../../data/services/doctor_orders_service.dart';
import '../../data/models/doctor_order.dart';
import '../../data/services/doctor_reviews_service.dart';
import '../../data/models/doctor_review.dart';
import '../patients/patient_orders_list_screen.dart';
import '../call/video_call_screen.dart';
import 'doctor_reviews_screen.dart';

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
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.infoOnly) {
      // Info-only view: no tabs, no chat, no orders
      return Scaffold(
        appBar: AppBar(
          title: const Text('Thông tin bác sĩ'),
          actions: [
            IconButton(
              icon: const Icon(Icons.rate_review),
              tooltip: 'Nhận xét',
              onPressed: () {
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
          ],
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
            : _buildInfoTab(infoOnly: true),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin bác sĩ'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          tabs: const [
            Tab(text: 'Thông tin bác sĩ'),
            Tab(text: 'Tin nhắn'),
          ],
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
              children: [_buildInfoTab(), _buildMessagesTab()],
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
            _infoRow('Tên bác sĩ', name),
            _infoRow('Email', email),
            _infoRow('Chuyên khoa', specialty),
            _infoRow('Kinh nghiệm (năm)', years),
            const SizedBox(height: 16),
            _buildRatingsSection(),
            const SizedBox(height: 16),
            if (!infoOnly) _buildDoctorOrdersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsSection() {
    // Patients can see rating and reviews; doctors can also see but cannot add
    return Consumer(
      builder: (context, ref, _) {
        final service = DoctorReviewsService();
        return FutureBuilder(
          future: ref.read(currentUserProvider.future),
          builder: (context, snap) {
            final currentUser = snap.data; // may be null initially
            final isPatient = currentUser?.isPatient == true;
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
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
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber),
                        const SizedBox(width: 8),
                        FutureBuilder<double>(
                          future: service.getAverageRating(widget.doctorId),
                          builder: (context, avgSnap) {
                            final avg = (avgSnap.data ?? 0).toStringAsFixed(1);
                            return Text(
                              'Đánh giá trung bình: $avg/5.0',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<DoctorReview>>(
                    stream: service.watchReviews(widget.doctorId, limit: 5),
                    builder: (context, rSnap) {
                      final reviews = rSnap.data ?? const <DoctorReview>[];
                      if (reviews.isEmpty) {
                        return const Text(
                          'Chưa có nhận xét nào. Hãy là người đầu tiên!',
                          style: TextStyle(color: AppColors.textSecondary),
                        );
                      }
                      return Column(
                        children: [
                          for (final r in reviews) ...[
                            _reviewTile(r),
                            const SizedBox(height: 8),
                          ],
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
  }

  void _showAddReviewSheet(DoctorReviewsService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final commentCtl = TextEditingController();
        int rating = 5;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Consumer(
            builder: (context, ref, _) {
              return FutureBuilder(
                future: ref.read(currentUserProvider.future),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final user = snap.data!;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đánh giá bác sĩ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (int i = 1; i <= 5; i++)
                              IconButton(
                                icon: Icon(
                                  i <= rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                ),
                                onPressed: () {
                                  rating = i;
                                  // force rebuild of sheet
                                  (ctx as Element).markNeedsBuild();
                                },
                              ),
                          ],
                        ),
                        TextField(
                          controller: commentCtl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Nhận xét (tuỳ chọn)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await service.upsertReview(
                                  doctorId: widget.doctorId,
                                  patientId: user.uid,
                                  patientName: user.name,
                                  rating: rating,
                                  comment: commentCtl.text.trim().isEmpty
                                      ? null
                                      : commentCtl.text.trim(),
                                );
                                if (!mounted) return;
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã gửi đánh giá'),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gửi đánh giá thất bại: $e'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Gửi'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _reviewTile(DoctorReview r) {
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
          const Icon(Icons.person, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.patientName.isEmpty ? 'Người dùng' : r.patientName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('${r.rating}/5'),
                      ],
                    ),
                  ],
                ),
                if ((r.comment ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r.comment!),
                ],
              ],
            ),
          ),
        ],
      ),
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

            final service = DoctorOrdersService();
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
                    stream: service.watchOrders(
                      patientId: currentUser.uid,
                      doctorId: widget.doctorId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
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
                            itemBuilder: (context, i) => _orderTile(preview[i]),
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
    return Consumer(
      builder: (context, ref, _) {
        return FutureBuilder(
          future: ref.read(currentUserProvider.future),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final currentUser = snap.data!;
            final otherId = widget.doctorId;
            if (currentUser.uid == otherId) {
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
                      onPressed: () {
                        final channel = _buildChannelName(
                          currentUser.uid,
                          otherId,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                VideoCallScreen(channelName: channel),
                          ),
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
                      return ListView.builder(
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
                              child: Text(m.text),
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
                        Expanded(
                          child: TextField(
                            controller: controller,
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

  String _buildChannelName(String a, String b) {
    return (a.compareTo(b) <= 0) ? '${a}_$b' : '${b}_$a';
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
