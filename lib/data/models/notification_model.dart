import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  aiAlert('ai_alert'),
  doctorFeedback('doctor_feedback'),
  appointment('appointment'),
  reminder('reminder'),
  other('other');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String? v) {
    switch (v) {
      case 'ai_alert':
        return NotificationType.aiAlert;
      case 'doctor_feedback':
        return NotificationType.doctorFeedback;
      case 'appointment':
        return NotificationType.appointment;
      case 'reminder':
        return NotificationType.reminder;
      default:
        return NotificationType.other;
    }
  }
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.data,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    final created = json['createdAt'];
    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is String) {
      createdAt = DateTime.tryParse(created) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }
    return AppNotification(
      id: doc.id,
      userId: (json['userId'] ?? '') as String,
      type: NotificationType.fromString(json['type'] as String?),
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      createdAt: createdAt,
      isRead: (json['isRead'] ?? false) as bool,
      data: (json['data'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type.value,
      'title': title,
      'body': body,
      'createdAt': createdAt,
      'isRead': isRead,
      if (data != null) 'data': data,
    };
  }
}
