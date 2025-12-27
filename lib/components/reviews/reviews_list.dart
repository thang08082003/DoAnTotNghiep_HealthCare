import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/resources/gene/app_colors.dart';
import '../../data/models/doctor_review.dart';
import '../../viewmodels/reviews/doctor_reviews_view_model.dart';
import './inline_user_avatar.dart';

class ReviewsList extends ConsumerWidget {
  final String doctorId;
  final DoctorReviewsViewModel reviewsVm;
  final int? limit; // null = full list
  final void Function(DoctorReview r)? onEdit;
  final void Function(DoctorReview r)? onDelete;

  const ReviewsList({
    super.key,
    required this.doctorId,
    required this.reviewsVm,
    this.limit,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<DoctorReview>>(
      stream: reviewsVm.watchReviews(doctorId, limit: limit),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snap.data ?? const <DoctorReview>[];
        if (reviews.isEmpty) {
          return const Text(
            'Chưa có nhận xét nào. Hãy là người đầu tiên!',
            style: TextStyle(color: AppColors.textSecondary),
          );
        }
        return ListView.separated(
          shrinkWrap: limit != null,
          physics: limit != null ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.all(0),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ReviewTile(
            review: reviews[i],
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final DoctorReview review;
  final void Function(DoctorReview r)? onEdit;
  final void Function(DoctorReview r)? onDelete;
  const _ReviewTile({required this.review, this.onEdit, this.onDelete});

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
          InlineUserAvatar(
            userId: r.patientId,
            initialUrl: r.patientAvatarUrl,
            displayName: r.patientName,
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
                    if (onEdit != null || onDelete != null) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit?.call(r);
                          } else if (value == 'delete') {
                            onDelete?.call(r);
                          }
                        },
                        itemBuilder: (context) => [
                          if (onEdit != null)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Sửa'),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Xoá'),
                            ),
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
