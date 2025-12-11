import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_review.dart';
import '../../data/services/doctor_reviews_service.dart';
import '../../components/reviews/reviews_summary.dart';
import '../../components/reviews/reviews_list.dart';
import '../../components/reviews/review_editor_sheet.dart';
import '../../components/dialog/custom_dialog.dart';
import '../../viewmodels/reviews/doctor_reviews_view_model.dart';
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
