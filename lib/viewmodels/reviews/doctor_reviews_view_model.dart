import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/doctor_reviews_repository.dart';
import '../../data/models/doctor_review.dart';

class DoctorReviewsViewModel {
  final DoctorReviewsRepository _repo = DoctorReviewsRepository();

  Future<double> getAverageRating(String doctorId) {
    return _repo.getAverageRating(doctorId);
  }

  Stream<List<DoctorReview>> watchReviews(String doctorId, {int? limit}) {
    return _repo.watchReviews(doctorId, limit: limit);
  }

  Future<void> upsertReview({
    required String doctorId,
    required String patientId,
    required String patientName,
    String? patientAvatarUrl,
    required int rating,
    String? comment,
  }) {
    return _repo.upsertReview(
      doctorId: doctorId,
      patientId: patientId,
      patientName: patientName,
      patientAvatarUrl: patientAvatarUrl,
      rating: rating,
      comment: comment,
    );
  }

  Future<void> deleteReview({
    required String doctorId,
    required String patientId,
  }) {
    return _repo.deleteReview(doctorId: doctorId, patientId: patientId);
  }
}

final doctorReviewsViewModelProvider = Provider<DoctorReviewsViewModel>((ref) {
  return DoctorReviewsViewModel();
});
