import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_review.dart';
import '../../data/services/doctor_reviews_service.dart';
import '../../components/reviews/reviews_summary.dart';
import '../../components/reviews/reviews_list.dart';
import '../../components/reviews/review_editor_sheet.dart';
import '../../components/dialog/custom_dialog.dart';
import '../../viewmodels/reviews/doctor_reviews_view_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../data/services/follow_request_service.dart';

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
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ReviewsSummary(
              doctorId: doctorId,
              reviewsVm: DoctorReviewsViewModel(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder(
              future: ref.read(currentUserProvider.future),
              builder: (context, userSnap) {
                final currentUser = userSnap.data;
                // final currentUid = currentUser?.uid; // not needed currently
                final isPatient = (currentUser?.isPatient ?? false) == true;
                final vm = DoctorReviewsViewModel();
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ReviewsList(
                    doctorId: doctorId,
                    reviewsVm: vm,
                    onEdit: isPatient
                        ? (r) => ReviewEditorSheet.show(
                            context: context,
                            doctorId: doctorId,
                            reviewsVm: vm,
                            existing: r,
                          )
                        : null,
                    onDelete: isPatient
                        ? (r) => _confirmAndDelete(context, service, r)
                        : null,
                  ),
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
                    onPressed: () => ReviewEditorSheet.show(
                      context: context,
                      doctorId: doctorId,
                      reviewsVm: DoctorReviewsViewModel(),
                    ),
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
    final confirmed = await CustomDialog.showConfirmation(
      context: context,
      title: 'Xoá nhận xét',
      message: 'Bạn có chắc muốn xoá nhận xét này?',
      confirmText: 'Xoá',
      cancelText: 'Huỷ',
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

  // Replaced by shared ReviewEditorSheet
}

// replaced by shared ReviewsList

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
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }
}

class _ReviewAvatar extends ConsumerStatefulWidget {
  final String patientId;
  final String? initialUrl;
  final String name;
  const _ReviewAvatar({
    required this.patientId,
    required this.initialUrl,
    required this.name,
  });

  @override
  ConsumerState<_ReviewAvatar> createState() => _ReviewAvatarState();
}

class _ReviewAvatarState extends ConsumerState<_ReviewAvatar> {
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
      final userRepo = ref.read(userRepositoryProvider);
      final u = await userRepo.getUserById(widget.patientId);
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
