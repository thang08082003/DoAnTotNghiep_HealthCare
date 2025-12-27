import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/doctor_review.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/reviews/doctor_reviews_view_model.dart';

class ReviewEditorSheet {
  static Future<void> show({
    required BuildContext context,
    required String doctorId,
    required DoctorReviewsViewModel reviewsVm,
    DoctorReview? existing,
  }) async {
    await showModalBottomSheet(
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
                  return StatefulBuilder(
                    builder: (context, setState) => SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existing == null
                                ? 'Đánh giá bác sĩ'
                                : 'Sửa đánh giá',
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
                                    i <= rating
                                        ? Icons.star
                                        : Icons.star_border,
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
                                      content: Text(
                                        'Nhận xét vượt quá 200 ký tự',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await reviewsVm.upsertReview(
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
                                      content: Text(
                                        'Gửi đánh giá thất bại: $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                existing == null ? 'Gửi' : 'Cập nhật',
                              ),
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
        );
      },
    );
  }
}
