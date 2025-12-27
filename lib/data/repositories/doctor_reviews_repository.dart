import '../services/doctor_reviews_service.dart';
import '../models/doctor_review.dart';

class DoctorReviewsRepository {
  final DoctorReviewsService _service;
  DoctorReviewsRepository({DoctorReviewsService? service})
    : _service = service ?? DoctorReviewsService();

  Future<double> getAverageRating(String doctorId) {
    return _service.getAverageRating(doctorId);
  }

  Stream<List<DoctorReview>> watchReviews(String doctorId, {int? limit}) {
    return _service.watchReviews(doctorId, limit: limit);
  }

  Future<void> upsertReview({
    required String doctorId,
    required String patientId,
    required String patientName,
    String? patientAvatarUrl,
    required int rating,
    String? comment,
  }) {
    return _service.upsertReview(
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
    return _service.deleteReview(doctorId: doctorId, patientId: patientId);
  }
}
