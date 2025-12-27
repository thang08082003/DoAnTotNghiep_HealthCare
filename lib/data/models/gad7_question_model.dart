/// Model cho câu hỏi GAD-7 (Generalized Anxiety Disorder-7)
/// Bộ câu hỏi đánh giá rối loạn lo âu

class GAD7Question {
  final int id;
  final String question;

  const GAD7Question({required this.id, required this.question});

  /// Danh sách 7 câu hỏi GAD-7 chuẩn
  static const List<GAD7Question> questions = [
    GAD7Question(id: 1, question: 'Cảm thấy lo lắng, bồn chồn hoặc căng thẳng'),
    GAD7Question(
      id: 2,
      question: 'Không thể ngừng lo lắng hoặc kiểm soát sự lo lắng',
    ),
    GAD7Question(
      id: 3,
      question: 'Lo lắng quá nhiều về những chuyện khác nhau',
    ),
    GAD7Question(id: 4, question: 'Khó thư giãn'),
    GAD7Question(id: 5, question: 'Bồn chồn đến mức khó có thể ngồi yên'),
    GAD7Question(id: 6, question: 'Dễ bực bội hoặc cáu kỉnh'),
    GAD7Question(
      id: 7,
      question: 'Cảm thấy sợ hãi như thể có chuyện khủng khiếp sắp xảy ra',
    ),
  ];

  /// Các lựa chọn trả lời (0-3 điểm)
  static const Map<int, String> answerOptions = {
    0: 'Không bao giờ',
    1: 'Vài ngày',
    2: 'Hơn một nửa số ngày',
    3: 'Gần như mỗi ngày',
  };
}

/// Model cho câu trả lời GAD-7
class GAD7Answer {
  final int questionId;
  final int score; // 0-3

  const GAD7Answer({required this.questionId, required this.score});

  Map<String, dynamic> toMap() {
    return {'questionId': questionId, 'score': score};
  }

  factory GAD7Answer.fromMap(Map<String, dynamic> map) {
    return GAD7Answer(
      questionId: map['questionId'] as int,
      score: map['score'] as int,
    );
  }
}
