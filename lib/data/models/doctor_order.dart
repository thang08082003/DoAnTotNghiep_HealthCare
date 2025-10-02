class DoctorOrder {
  final String id;
  final String doctorId;
  final String patientId;
  final String title; // e.g., Thuốc/Xét nghiệm/Chế độ
  final String? notes; // optional details
  final DateTime? createdAt;

  DoctorOrder({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.title,
    this.notes,
    this.createdAt,
  });

  factory DoctorOrder.fromJson(String id, Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['createdAt'];
    if (raw is String) {
      created = DateTime.tryParse(raw);
    } else if (raw != null && raw.toString().contains('Timestamp')) {
      // If Timestamp from Firestore
      try {
        created = (raw.toDate() as DateTime?);
      } catch (_) {}
    }

    return DoctorOrder(
      id: id,
      doctorId: json['doctorId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      createdAt: created,
    );
  }
}
