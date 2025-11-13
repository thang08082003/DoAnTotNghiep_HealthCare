import 'package:cloud_firestore/cloud_firestore.dart';

class FollowRequest {
  final String id; // Document ID: patientId_doctorId
  final String patientId;
  final String doctorId;
  final String status; // 'pending', 'accepted', 'rejected', 'cancelled'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Additional fields (will be fetched from users collection)
  final String patientName;
  final String? patientEmail;
  final String? patientAvatarUrl;

  const FollowRequest({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.status,
    this.createdAt,
    this.updatedAt,
    required this.patientName,
    this.patientEmail,
    this.patientAvatarUrl,
  });

  factory FollowRequest.fromFirestore(
    DocumentSnapshot doc,
    Map<String, dynamic> patientData,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return FollowRequest(
      id: doc.id,
      patientId: data['patientId'] as String,
      doctorId: data['doctorId'] as String,
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      patientName: patientData['name'] as String? ?? 'Unknown',
      patientEmail: patientData['email'] as String?,
      patientAvatarUrl: patientData['avatarUrl'] as String?,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
}
