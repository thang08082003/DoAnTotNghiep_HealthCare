import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho thuốc
class Medication {
  final String id;
  final String userId;
  final String name; // Tên thuốc
  final String? dosage; // Liều lượng (VD: 100mg, 2 viên)
  final String? frequency; // Tần suất (VD: 2 lần/ngày, sáng tối)
  final String? instructions; // Hướng dẫn sử dụng
  final DateTime? startDate; // Ngày bắt đầu
  final DateTime? endDate; // Ngày kết thúc (null = dùng lâu dài)
  final String? notes; // Ghi chú
  final bool isActive; // Đang sử dụng hay đã ngưng
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    this.dosage,
    this.frequency,
    this.instructions,
    this.startDate,
    this.endDate,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  factory Medication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Medication(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      dosage: data['dosage'],
      frequency: data['frequency'],
      instructions: data['instructions'],
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'instructions': instructions,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'notes': notes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? dosage,
    String? frequency,
    String? instructions,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      instructions: instructions ?? this.instructions,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
