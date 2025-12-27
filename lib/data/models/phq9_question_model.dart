/// Model cho câu hỏi PHQ-9 (Patient Health Questionnaire-9)
class PHQ9Question {
  final int id;
  final String question;
  final String? subtitle; // Mô tả thêm nếu cần

  const PHQ9Question({required this.id, required this.question, this.subtitle});

  /// Danh sách 9 câu hỏi PHQ-9 chuẩn
  static const List<PHQ9Question> questions = [
    PHQ9Question(
      id: 1,
      question: 'Ít quan tâm hoặc không vui khi làm việc gì',
      subtitle: 'Cảm thấy mất hứng thú với các hoạt động thường ngày',
    ),
    PHQ9Question(
      id: 2,
      question: 'Cảm thấy chán nản, buồn bã, hoặc tuyệt vọng',
      subtitle: 'Tâm trạng u ám, không vui',
    ),
    PHQ9Question(
      id: 3,
      question: 'Khó ngủ, ngủ không ngon, hoặc ngủ quá nhiều',
      subtitle: 'Các vấn đề về giấc ngủ',
    ),
    PHQ9Question(
      id: 4,
      question: 'Cảm thấy mệt mỏi hoặc thiếu năng lượng',
      subtitle: 'Mệt mỏi suốt ngày',
    ),
    PHQ9Question(
      id: 5,
      question: 'Ăn kém hoặc ăn quá nhiều',
      subtitle: 'Thay đổi cảm giác thèm ăn',
    ),
    PHQ9Question(
      id: 6,
      question:
          'Cảm thấy không tốt về bản thân - hoặc cảm thấy mình thất bại hoặc đã làm thất vọng bản thân hay gia đình',
      subtitle: 'Tự ti, tự trách',
    ),
    PHQ9Question(
      id: 7,
      question: 'Khó tập trung vào công việc, như đọc báo hoặc xem TV',
      subtitle: 'Khó tập trung, dễ phân tâm',
    ),
    PHQ9Question(
      id: 8,
      question:
          'Di chuyển hoặc nói chuyện chậm chạp đến mức người khác để ý - hoặc ngược lại, bồn chồn không yên đến mức bạn đi lại nhiều hơn bình thường',
      subtitle: 'Thay đổi về vận động và lời nói',
    ),
    PHQ9Question(
      id: 9,
      question:
          'Nghĩ rằng tốt hơn là chết hoặc tự làm hại bản thân theo cách nào đó',
      subtitle: 'Ý nghĩ tiêu cực nghiêm trọng',
    ),
  ];

  /// Các lựa chọn trả lời và điểm số
  static const Map<int, String> answerOptions = {
    0: 'Không bao giờ',
    1: 'Vài ngày',
    2: 'Hơn một nửa số ngày',
    3: 'Gần như mỗi ngày',
  };
}

/// Model cho câu trả lời PHQ-9
class PHQ9Answer {
  final int questionId;
  final int score; // 0-3

  const PHQ9Answer({required this.questionId, required this.score});

  Map<String, dynamic> toMap() {
    return {'questionId': questionId, 'score': score};
  }

  factory PHQ9Answer.fromMap(Map<String, dynamic> map) {
    return PHQ9Answer(
      questionId: map['questionId'] ?? 0,
      score: map['score'] ?? 0,
    );
  }
}
