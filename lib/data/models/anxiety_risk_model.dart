import 'package:cloud_firestore/cloud_firestore.dart';
import 'gad7_question_model.dart';

/// Model cho đánh giá nguy cơ lo âu dựa trên GAD-7
class AnxietyRisk {
  final String id;
  final String userId;
  final int score; // 0-21
  final String level; // minimal, mild, moderate, severe
  final List<GAD7Answer> answers;
  final DateTime createdAt;

  const AnxietyRisk({
    required this.id,
    required this.userId,
    required this.score,
    required this.level,
    required this.answers,
    required this.createdAt,
  });

  /// Tính mức độ lo âu dựa trên điểm GAD-7
  /// 0-4: Minimal anxiety
  /// 5-9: Mild anxiety
  /// 10-14: Moderate anxiety
  /// 15-21: Severe anxiety
  static String calculateLevel(int score) {
    if (score <= 4) return 'minimal';
    if (score <= 9) return 'mild';
    if (score <= 14) return 'moderate';
    return 'severe';
  }

  /// Mô tả mức độ bằng tiếng Việt
  String get levelDescription {
    switch (level) {
      case 'minimal':
        return 'Lo âu tối thiểu';
      case 'mild':
        return 'Lo âu nhẹ';
      case 'moderate':
        return 'Lo âu trung bình';
      case 'severe':
        return 'Lo âu nặng';
      default:
        return 'Không xác định';
    }
  }

  /// Lời khuyên dựa trên mức độ
  String get recommendation {
    switch (level) {
      case 'minimal':
        return 'Bạn đang có mức độ lo âu tối thiểu. Hãy duy trì lối sống lành mạnh và các hoạt động thư giãn.';
      case 'mild':
        return 'Bạn có dấu hiệu lo âu nhẹ. Hãy thử các kỹ thuật thư giãn, tập thể dục đều đặn và duy trì giấc ngủ tốt.';
      case 'moderate':
        return 'Bạn đang có lo âu ở mức trung bình. Nên cân nhắc tham khảo ý kiến bác sĩ hoặc chuyên gia tâm lý.';
      case 'severe':
        return 'Bạn có dấu hiệu lo âu nặng. Nên gặp bác sĩ hoặc chuyên gia sức khỏe tâm thần để được tư vấn và hỗ trợ kịp thời.';
      default:
        return '';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'score': score,
      'level': level,
      'answers': answers.map((a) => a.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AnxietyRisk.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return AnxietyRisk(
      id: snapshot.id,
      userId: data['userId'] as String,
      score: data['score'] as int,
      level: data['level'] as String,
      answers: (data['answers'] as List<dynamic>)
          .map((a) => GAD7Answer.fromMap(a as Map<String, dynamic>))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  AnxietyRisk copyWith({
    String? id,
    String? userId,
    int? score,
    String? level,
    List<GAD7Answer>? answers,
    DateTime? createdAt,
  }) {
    return AnxietyRisk(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      score: score ?? this.score,
      level: level ?? this.level,
      answers: answers ?? this.answers,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
