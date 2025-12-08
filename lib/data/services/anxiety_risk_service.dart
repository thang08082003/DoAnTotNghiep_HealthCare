import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anxiety_risk_model.dart';
import '../models/gad7_question_model.dart';

/// Service xử lý CRUD cho đánh giá nguy cơ lo âu
class AnxietyRiskService {
  final FirebaseFirestore _firestore;

  AnxietyRiskService(this._firestore);

  /// Collection reference
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('anxiety_risks');

  /// Tạo đánh giá mới từ danh sách câu trả lời
  Future<void> createAssessment({
    required String userId,
    required List<GAD7Answer> answers,
  }) async {
    // Tính tổng điểm
    final score = answers.fold<int>(0, (sum, answer) => sum + answer.score);

    // Xác định mức độ
    final level = AnxietyRisk.calculateLevel(score);

    final assessment = AnxietyRisk(
      id: '',
      userId: userId,
      score: score,
      level: level,
      answers: answers,
      createdAt: DateTime.now(),
    );

    await _collection.add(assessment.toFirestore());
  }

  /// Lấy các đánh giá trong khoảng thời gian
  Stream<List<AnxietyRisk>> getAssessmentsByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AnxietyRisk.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy tất cả đánh giá của user
  Stream<List<AnxietyRisk>> getAllAssessments(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AnxietyRisk.fromFirestore(doc))
              .toList(),
        );
  }

  /// Xóa đánh giá
  Future<void> deleteAssessment(String assessmentId) async {
    await _collection.doc(assessmentId).delete();
  }
}

/// Provider cho AnxietyRiskService
final anxietyRiskServiceProvider = Provider<AnxietyRiskService>((ref) {
  return AnxietyRiskService(FirebaseFirestore.instance);
});
