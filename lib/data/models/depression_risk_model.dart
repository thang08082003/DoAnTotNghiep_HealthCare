import 'package:cloud_firestore/cloud_firestore.dart';
import 'phq9_question_model.dart';

/// Model cho đánh giá nguy cơ trầm cảm
class DepressionRisk {
  final String id;
  final String userId;
  final int score; // Điểm đánh giá (0-27 theo thang PHQ-9)
  final String
  level; // Mức độ: 'minimal', 'mild', 'moderate', 'moderately_severe', 'severe'
  final List<PHQ9Answer> answers; // Câu trả lời cho 9 câu hỏi
  final String? note; // Ghi chú thêm
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DepressionRisk({
    required this.id,
    required this.userId,
    required this.score,
    required this.level,
    required this.answers,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  /// Tạo DepressionRisk từ Firestore Document
  factory DepressionRisk.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final answersData = data['answers'] as List<dynamic>? ?? [];

    return DepressionRisk(
      id: doc.id,
      userId: data['userId'] ?? '',
      score: data['score'] ?? 0,
      level: data['level'] ?? 'minimal',
      answers: answersData
          .map((a) => PHQ9Answer.fromMap(a as Map<String, dynamic>))
          .toList(),
      note: data['note'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Chuyển đổi sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'score': score,
      'level': level,
      'answers': answers.map((a) => a.toMap()).toList(),
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Tính mức độ nguy cơ dựa trên điểm
  static String calculateLevel(int score) {
    if (score <= 4) return 'minimal';
    if (score <= 9) return 'mild';
    if (score <= 14) return 'moderate';
    if (score <= 19) return 'moderately_severe';
    return 'severe';
  }

  /// Lấy mô tả mức độ bằng tiếng Việt
  String get levelDescription {
    switch (level) {
      case 'minimal':
        return 'Tối thiểu';
      case 'mild':
        return 'Nhẹ';
      case 'moderate':
        return 'Trung bình';
      case 'moderately_severe':
        return 'Khá nghiêm trọng';
      case 'severe':
        return 'Nghiêm trọng';
      default:
        return 'Không xác định';
    }
  }

  /// Lấy màu sắc tương ứng với mức độ
  String get levelColor {
    switch (level) {
      case 'minimal':
        return 'green';
      case 'mild':
        return 'lightGreen';
      case 'moderate':
        return 'orange';
      case 'moderately_severe':
        return 'deepOrange';
      case 'severe':
        return 'red';
      default:
        return 'grey';
    }
  }

  /// Copy with method cho immutability
  DepressionRisk copyWith({
    String? id,
    String? userId,
    int? score,
    String? level,
    List<PHQ9Answer>? answers,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DepressionRisk(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      score: score ?? this.score,
      level: level ?? this.level,
      answers: answers ?? this.answers,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
