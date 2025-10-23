import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/reviews/doctor_reviews_view_model.dart';

class ReviewsSummary extends ConsumerWidget {
  final String doctorId;
  final DoctorReviewsViewModel reviewsVm;
  final VoidCallback? onTap;
  final bool compact;
  const ReviewsSummary({
    super.key,
    required this.doctorId,
    required this.reviewsVm,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = Row(
      children: [
        const Icon(Icons.star, color: Colors.amber),
        const SizedBox(width: 8),
        FutureBuilder<double>(
          future: reviewsVm.getAverageRating(doctorId),
          builder: (context, snap) {
            final avg = (snap.data ?? 0).toStringAsFixed(1);
            return Text(
              compact ? '$avg/5.0' : 'Đánh giá trung bình: $avg/5.0',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            );
          },
        ),
      ],
    );

    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}
