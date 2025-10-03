import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_review.dart';
import '../../data/services/doctor_reviews_service.dart';
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
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _reviewTile(reviews[i]),
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
              return FloatingActionButton.extended(
                onPressed: () => _showAddReviewSheet(context, ref, service),
                icon: const Icon(Icons.star),
                label: const Text('Đánh giá'),
              );
            },
          );
        },
      ),
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

  void _showAddReviewSheet(
    BuildContext context,
    WidgetRef ref,
    DoctorReviewsService service,
  ) {
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
                              onPressed: () => setState(() => rating = i),
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
                                doctorId: doctorId,
                                patientId: user.uid,
                                patientName: user.name,
                                rating: rating,
                                comment: commentCtl.text.trim().isEmpty
                                    ? null
                                    : commentCtl.text.trim(),
                              );
                              if (!context.mounted) return;
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
                ),
              );
            },
          ),
        );
      },
    );
  }
}
