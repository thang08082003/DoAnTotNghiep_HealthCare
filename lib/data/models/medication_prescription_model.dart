import 'package:cloud_firestore/cloud_firestore.dart';

enum PrescriptionStatus {
  pendingPatientReview, // Chờ bệnh nhân xem & phản hồi
  approvedByPatient, // Bệnh nhân đã chấp nhận
  rejected, // Bệnh nhân từ chối
  modificationRequested, // Bệnh nhân yêu cầu chỉnh sửa
  active, // Đang sử dụng (sau khi tạo medications + reminders)
  expired, // Hết hạn
}

extension PrescriptionStatusExtension on PrescriptionStatus {
  String get displayName {
    switch (this) {
      case PrescriptionStatus.pendingPatientReview:
        return 'Chờ xem & phản hồi';
      case PrescriptionStatus.approvedByPatient:
        return 'Đã chấp nhận';
      case PrescriptionStatus.rejected:
        return 'Từ chối';
      case PrescriptionStatus.modificationRequested:
        return 'Yêu cầu chỉnh sửa';
      case PrescriptionStatus.active:
        return 'Đang áp dụng';
      case PrescriptionStatus.expired:
        return 'Hết hạn';
    }
  }

  String get value {
    return toString().split('.').last;
  }

  static PrescriptionStatus fromString(String value) {
    return PrescriptionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PrescriptionStatus.pendingPatientReview,
    );
  }
}

/// Model cho đơn thuốc (chỉ định thuốc từ bác sĩ)
class MedicationPrescription {
  final String id;
  final String patientId; // ID bệnh nhân
  final String doctorId; // ID bác sĩ kê đơn
  final String doctorName; // Tên bác sĩ (để hiển thị)

  // Thông tin thuốc
  final String medicationName; // Tên thuốc (biệt dược hoặc hoạt chất)
  final String? concentration; // Hàm lượng/Nồng độ (VD: 500mg, 10ml)
  final String? quantity; // Số lượng (VD: 30 viên, 2 hộp)
  final String dosage; // Liều dùng (VD: 1 viên/lần, 2 lần/ngày)
  final String route; // Đường dùng (uống, tiêm, đặt, xịt...)
  final String? timing; // Thời điểm dùng (trước ăn, sau ăn, khi đau...)
  final String? specialInstructions; // Lưu ý đặc biệt

  // Thời gian sử dụng
  final DateTime startDate; // Ngày bắt đầu
  final int durationDays; // Thời hạn sử dụng (số ngày)
  final DateTime endDate; // Ngày kết thúc (auto = startDate + duration)
  final int renewalWindowDays; // Cửa sổ gia hạn (VD: 3 ngày trước khi hết)

  // Trạng thái
  final PrescriptionStatus status;
  final String?
  patientResponse; // Phản hồi của bệnh nhân (lý do từ chối/yêu cầu sửa)
  final double version; // Version tracking (1.0, 1.1, etc.)
  final int modificationRequestCount; // Số lần yêu cầu chỉnh sửa
  final bool requiresVideoCall; // Cần gọi video để giải quyết

  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;

  MedicationPrescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.medicationName,
    this.concentration,
    this.quantity,
    required this.dosage,
    required this.route,
    this.timing,
    this.specialInstructions,
    required this.startDate,
    required this.durationDays,
    required this.endDate,
    this.renewalWindowDays = 3,
    this.status = PrescriptionStatus.pendingPatientReview,
    this.patientResponse,
    this.version = 1.0,
    this.modificationRequestCount = 0,
    this.requiresVideoCall = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory MedicationPrescription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicationPrescription(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      medicationName: data['medicationName'] ?? '',
      concentration: data['concentration'],
      quantity: data['quantity'],
      dosage: data['dosage'] ?? '',
      route: data['route'] ?? '',
      timing: data['timing'],
      specialInstructions: data['specialInstructions'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      durationDays: data['durationDays'] ?? 0,
      endDate: (data['endDate'] as Timestamp).toDate(),
      renewalWindowDays: data['renewalWindowDays'] ?? 3,
      status: PrescriptionStatusExtension.fromString(
        data['status'] ?? 'pendingPatientReview',
      ),
      patientResponse: data['patientResponse'],
      version: (data['version'] ?? 1.0).toDouble(),
      modificationRequestCount: data['modificationRequestCount'] ?? 0,
      requiresVideoCall: data['requiresVideoCall'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'medicationName': medicationName,
      'concentration': concentration,
      'quantity': quantity,
      'dosage': dosage,
      'route': route,
      'timing': timing,
      'specialInstructions': specialInstructions,
      'startDate': Timestamp.fromDate(startDate),
      'durationDays': durationDays,
      'endDate': Timestamp.fromDate(endDate),
      'renewalWindowDays': renewalWindowDays,
      'status': status.value,
      'patientResponse': patientResponse,
      'version': version,
      'modificationRequestCount': modificationRequestCount,
      'requiresVideoCall': requiresVideoCall,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  MedicationPrescription copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? doctorName,
    String? medicationName,
    String? concentration,
    String? quantity,
    String? dosage,
    String? route,
    String? timing,
    String? specialInstructions,
    DateTime? startDate,
    int? durationDays,
    DateTime? endDate,
    int? renewalWindowDays,
    PrescriptionStatus? status,
    String? patientResponse,
    double? version,
    int? modificationRequestCount,
    bool? requiresVideoCall,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationPrescription(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      medicationName: medicationName ?? this.medicationName,
      concentration: concentration ?? this.concentration,
      quantity: quantity ?? this.quantity,
      dosage: dosage ?? this.dosage,
      route: route ?? this.route,
      timing: timing ?? this.timing,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      startDate: startDate ?? this.startDate,
      durationDays: durationDays ?? this.durationDays,
      endDate: endDate ?? this.endDate,
      renewalWindowDays: renewalWindowDays ?? this.renewalWindowDays,
      status: status ?? this.status,
      patientResponse: patientResponse ?? this.patientResponse,
      version: version ?? this.version,
      modificationRequestCount:
          modificationRequestCount ?? this.modificationRequestCount,
      requiresVideoCall: requiresVideoCall ?? this.requiresVideoCall,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if prescription needs renewal notification
  bool needsRenewalNotification() {
    final now = DateTime.now();
    final renewalDate = endDate.subtract(Duration(days: renewalWindowDays));
    return now.isAfter(renewalDate) && now.isBefore(endDate);
  }

  /// Check if prescription is expired
  bool isExpired() {
    return DateTime.now().isAfter(endDate);
  }
}
