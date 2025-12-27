import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/depression_risk_model.dart';
import '../models/phq9_question_model.dart';

/// Service để quản lý đánh giá nguy cơ trầm cảm
class DepressionRiskService {
  final FirebaseFirestore _firestore;

  DepressionRiskService(this._firestore);

  /// Tham chiếu đến collection depression_risks
  CollectionReference get _collection =>
      _firestore.collection('depression_risks');

  /// Tạo đánh giá mới từ câu trả lời PHQ-9
  Future<String> createAssessment({
    required String userId,
    required List<PHQ9Answer> answers,
    String? note,
  }) async {
    // Tính tổng điểm
    final score = answers.fold<int>(0, (sum, answer) => sum + answer.score);
    final level = DepressionRisk.calculateLevel(score);
    final now = DateTime.now();

    final doc = await _collection.add({
      'userId': userId,
      'score': score,
      'level': level,
      'answers': answers.map((a) => a.toMap()).toList(),
      'note': note,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': null,
    });

    return doc.id;
  }

  /// Lấy assessments trong khoảng thời gian
  Stream<List<DepressionRisk>> getAssessmentsByDateRange({
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
              .map((doc) => DepressionRisk.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy tất cả assessments của user
  Stream<List<DepressionRisk>> getAllAssessments(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DepressionRisk.fromFirestore(doc))
              .toList(),
        );
  }

  /// Xóa đánh giá
  Future<void> deleteAssessment(String assessmentId) async {
    await _collection.doc(assessmentId).delete();
  }
}

/// Provider cho DepressionRiskService
final depressionRiskServiceProvider = Provider<DepressionRiskService>((ref) {
  return DepressionRiskService(FirebaseFirestore.instance);
});
