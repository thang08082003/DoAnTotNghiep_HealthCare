import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_review.dart';
import '../../data/services/doctor_reviews_service.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../data/services/follow_request_service.dart';
import '../../data/services/user_service.dart';

class DoctorReviewsScreen extends ConsumerWidget {
  final String doctorId;
  final String? doctorName;
  const DoctorReviewsScreen({
    super.key,
    required this.doctorId,
    this.doctorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = DoctorReviewsService();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nhận xét ${doctorName != null && doctorName!.isNotEmpty ? '– $doctorName' : ''}'
              .trim(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                FutureBuilder<double>(
                  future: service.getAverageRating(doctorId),
                  builder: (context, snap) {
                    final avg = (snap.data ?? 0).toStringAsFixed(1);
                    return Text(
                      'Đánh giá trung bình: $avg/5.0',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<DoctorReview>>(
              stream: service.watchReviews(doctorId),
              builder: (context, snap) {
                final reviews = snap.data ?? const <DoctorReview>[];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (reviews.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có nhận xét nào',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return FutureBuilder(
                  future: ref.read(currentUserProvider.future),
                  builder: (context, userSnap) {
                    final currentUser = userSnap.data;
                    final currentUid = currentUser?.uid;
                    final isPatient = (currentUser?.isPatient ?? false) == true;
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = reviews[i];
                        final isMine =
                            isPatient &&
                            currentUid != null &&
                            currentUid == r.patientId;
                        return _ReviewTile(
                          review: r,
                          isMine: isMine,
                          onEdit: isMine
                              ? () => _showAddOrEditReviewSheet(
                                  context,
                                  ref,
                                  service,
                                  existing: r,
                                )
                              : null,
                          onDelete: isMine
                              ? () => _confirmAndDelete(context, service, r)
                              : null,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder(
        future: ref.read(currentUserProvider.future),
        builder: (context, snapUser) {
          if (!snapUser.hasData) return const SizedBox.shrink();
          final user = snapUser.data!;
          if (user.isPatient != true) return const SizedBox.shrink();
          return FutureBuilder<String?>(
            future: FollowRequestService.getRequestStatus(
              patientId: user.uid,
              doctorId: doctorId,
            ),
            builder: (context, snapStatus) {
              final accepted = snapStatus.data == 'accepted';
              if (!accepted) return const SizedBox.shrink();
              // Only allow adding a review if the current patient has not reviewed yet
              return StreamBuilder<List<DoctorReview>>(
                stream: service.watchReviews(doctorId),
                builder: (context, snapReviews) {
                  final reviews = snapReviews.data ?? const <DoctorReview>[];
                  final hasMine = reviews.any((r) => r.patientId == user.uid);
                  if (hasMine) return const SizedBox.shrink();
                  return FloatingActionButton.extended(
                    onPressed: () =>
                        _showAddOrEditReviewSheet(context, ref, service),
                    icon: const Icon(Icons.star),
                    label: const Text('Đánh giá'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    DoctorReviewsService service,
    DoctorReview r,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá nhận xét'),
        content: const Text('Bạn có chắc muốn xoá nhận xét này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await service.deleteReview(doctorId: doctorId, patientId: r.patientId);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã xoá nhận xét')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Xoá thất bại: $e')));
        }
      }
    }
  }

  void _showAddOrEditReviewSheet(
    BuildContext context,
    WidgetRef ref,
    DoctorReviewsService service, {
    DoctorReview? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final initialComment = existing?.comment ?? '';
        final commentCtl = TextEditingController(text: initialComment);
        int rating = existing?.rating ?? 5;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: FutureBuilder(
            future: ref.read(currentUserProvider.future),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final user = snap.data!;
              return StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing == null ? 'Đánh giá bác sĩ' : 'Sửa đánh giá',
                        style: const TextStyle(
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
                              onPressed: () => setState(() => rating = i),
                            ),
                        ],
                      ),
                      StatefulBuilder(
                        builder: (c, setStateField) {
                          final len = commentCtl.text.characters.length;
                          final max = 200;
                          final over = len > max;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: commentCtl,
                                maxLines: 4,
                                maxLength: 200,
                                onChanged: (_) => setStateField(() {}),
                                decoration: InputDecoration(
                                  labelText:
                                      'Nhận xét (tối đa 200 ký tự, tuỳ chọn)',
                                  border: const OutlineInputBorder(),
                                  counterText: '$len/200',
                                  counterStyle: TextStyle(
                                    fontSize: 12,
                                    color: over ? Colors.red : Colors.grey,
                                  ),
                                ),
                              ),
                              if (over)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Vượt quá 200 ký tự',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () async {
                            final text = commentCtl.text.trim();
                            if (text.isNotEmpty &&
                                text.characters.length > 200) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nhận xét vượt quá 200 ký tự'),
                                ),
                              );
                              return;
                            }
                            try {
                              await service.upsertReview(
                                doctorId: doctorId,
                                patientId: user.uid,
                                patientName: user.name,
                                patientAvatarUrl: user.avatarUrl,
                                rating: rating,
                                comment: text.isEmpty ? null : text,
                              );
                              if (!context.mounted) return;
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    existing == null
                                        ? 'Đã gửi đánh giá'
                                        : 'Đã cập nhật đánh giá',
                                  ),
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
                          child: Text(existing == null ? 'Gửi' : 'Cập nhật'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final DoctorReview review;
  final bool isMine;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _ReviewTile({
    required this.review,
    this.isMine = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = review;
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
          _ReviewAvatar(
            patientId: r.patientId,
            initialUrl: r.patientAvatarUrl,
            name: r.patientName,
          ),
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
                    if (isMine) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit?.call();
                          } else if (value == 'delete') {
                            onDelete?.call();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Sửa')),
                          PopupMenuItem(value: 'delete', child: Text('Xoá')),
                        ],
                      ),
                    ],
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
}

class _AvatarThumb extends StatelessWidget {
  final String? url;
  final String name;
  const _AvatarThumb({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromName(name);
    final hasUrl = url != null && url!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 40,
        height: 40,
        color: Colors.grey.withValues(alpha: 0.15),
        child: hasUrl
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _FallbackAvatar(initials),
                loadingBuilder: (c, w, progress) {
                  if (progress == null) return w;
                  return const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              )
            : _FallbackAvatar(initials),
      ),
    );
  }

  String _initialsFromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1)
      return parts.first.characters.take(1).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }
}

class _ReviewAvatar extends StatefulWidget {
  final String patientId;
  final String? initialUrl;
  final String name;
  const _ReviewAvatar({
    required this.patientId,
    required this.initialUrl,
    required this.name,
  });

  @override
  State<_ReviewAvatar> createState() => _ReviewAvatarState();
}

class _ReviewAvatarState extends State<_ReviewAvatar> {
  String? _url;
  bool _loading = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
    if (_url == null || _url!.isEmpty) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (_tried) return;
    _tried = true;
    setState(() => _loading = true);
    try {
      final svc = UserService();
      final u = await svc.getUserById(widget.patientId);
      if (!mounted) return;
      setState(() {
        _url = u?.avatarUrl;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && (_url == null || _url!.isEmpty)) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return _AvatarThumb(url: _url, name: widget.name);
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String initials;
  const _FallbackAvatar(this.initials);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
