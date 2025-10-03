import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_review.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class DoctorReviewsService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reviewsCol(String doctorId) =>
      _db.collection('users').doc(doctorId).collection('reviews');

  Stream<List<DoctorReview>> watchReviews(String doctorId, {int? limit}) {
    Query<Map<String, dynamic>> q = _reviewsCol(
      doctorId,
    ).orderBy('updatedAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map(
      (s) => s.docs.map((d) => DoctorReview.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<double> getAverageRating(String doctorId) async {
    final snap = await _reviewsCol(doctorId).get();
    if (snap.docs.isEmpty) return 0;
    final list = snap.docs
        .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0)
        .toList();
    if (list.isEmpty) return 0;
    final sum = list.reduce((a, b) => a + b);
    return sum / list.length;
  }

  Future<void> upsertReview({
    required String doctorId,
    required String patientId,
    required String patientName,
    String? patientAvatarUrl,
    required int rating, // 1..5
    String? comment,
  }) async {
    final doc = _reviewsCol(doctorId).doc(patientId); // one per patient
    await doc.set({
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'patientAvatarUrl': patientAvatarUrl,
      'rating': rating,
      'comment': comment,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Notify the doctor that a patient has submitted/updated a review
    final trimmedComment = (comment ?? '').trim();
    final snippet = trimmedComment.isEmpty
        ? ''
        : (trimmedComment.length > 120
              ? '${trimmedComment.substring(0, 117)}...'
              : trimmedComment);
    final body = snippet.isEmpty
        ? 'Đã đánh giá $rating/5'
        : 'Đã đánh giá $rating/5: $snippet';

    await NotificationService.createNotification(
      toUserId: doctorId,
      senderId: patientId,
      type: NotificationType.doctorFeedback,
      title: 'Nhận xét mới từ $patientName',
      body: body,
      data: <String, dynamic>{
        'doctorId': doctorId,
        'patientId': patientId,
        'patientName': patientName,
        'rating': rating,
        if (trimmedComment.isNotEmpty) 'comment': trimmedComment,
      },
    );
  }

  Future<void> deleteReview({
    required String doctorId,
    required String patientId,
  }) async {
    await _reviewsCol(doctorId).doc(patientId).delete();
  }
}
