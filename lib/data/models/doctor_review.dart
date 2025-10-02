class DoctorReview {
  final String id; // doc id = patientId
  final String doctorId;
  final String patientId;
  final String patientName;
  final int rating; // 1..5
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DoctorReview({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
  });

  factory DoctorReview.fromMap(String id, Map<String, dynamic> data) {
    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) {
        return DateTime.tryParse(v);
      }
      final ts = data['createdAt'];
      try {
        // Firestore Timestamp has toDate
        return ts?.toDate();
      } catch (_) {
        return null;
      }
    }

    return DoctorReview(
      id: id,
      doctorId: data['doctorId'] as String? ?? '',
      patientId: data['patientId'] as String? ?? '',
      patientName: data['patientName'] as String? ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] as String?,
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }
}
