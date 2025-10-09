import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus { ringing, accepted, declined, ended }

class CallSession {
  final String id;
  final String callerId;
  final String calleeId;
  final String channelName;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CallSession({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.channelName,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory CallSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    CallStatus parseStatus(String? s) {
      switch (s) {
        case 'accepted':
          return CallStatus.accepted;
        case 'declined':
          return CallStatus.declined;
        case 'ended':
          return CallStatus.ended;
        case 'ringing':
        default:
          return CallStatus.ringing;
      }
    }

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    return CallSession(
      id: doc.id,
      callerId: data['callerId'] as String,
      calleeId: data['calleeId'] as String,
      channelName: data['channelName'] as String,
      status: parseStatus(data['status'] as String?),
      createdAt: parseTs(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? parseTs(data['updatedAt']) : null,
    );
  }
}
