import 'doctor_model.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final String? diseaseFocus;
  final String? assignedDoctorId;
  // Patient-only optional fields
  final String? phone;
  final int? age;
  final String? gender;
  final String? medicalHistory;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.diseaseFocus,
    this.assignedDoctorId,
    this.phone,
    this.age,
    this.gender,
    this.medicalHistory,
    required this.createdAt,
  });

  // Factory constructor từ JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromString(json['role'] as String),
      avatarUrl: json['avatarUrl'] as String?,
      diseaseFocus: json['diseaseFocus'] as String?,
      assignedDoctorId: json['assignedDoctorId'] as String?,
      phone: json['phone'] as String?,
      age: json['age'] is int
          ? json['age'] as int
          : (json['age'] is String
                ? int.tryParse(json['age'] as String)
                : null),
      gender: json['gender'] as String?,
      medicalHistory: json['medicalHistory'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // Chuyển đối tượng thành JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.value,
      'avatarUrl': avatarUrl,
      'diseaseFocus': diseaseFocus,
      'assignedDoctorId': assignedDoctorId,
      'phone': phone,
      'age': age,
      'gender': gender,
      'medicalHistory': medicalHistory,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Copy with method để tạo bản sao với một số thay đổi
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    UserRole? role,
    String? avatarUrl,
    String? diseaseFocus,
    String? assignedDoctorId,
    String? phone,
    int? age,
    String? gender,
    String? medicalHistory,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      diseaseFocus: diseaseFocus ?? this.diseaseFocus,
      assignedDoctorId: assignedDoctorId ?? this.assignedDoctorId,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel{uid: $uid, name: $name, email: $email, role: $role, avatarUrl: $avatarUrl, diseaseFocus: $diseaseFocus, assignedDoctorId: $assignedDoctorId, phone: $phone, age: $age, gender: $gender, medicalHistory: $medicalHistory, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          name == other.name &&
          email == other.email &&
          role == other.role &&
          avatarUrl == other.avatarUrl &&
          diseaseFocus == other.diseaseFocus &&
          assignedDoctorId == other.assignedDoctorId &&
          phone == other.phone &&
          age == other.age &&
          gender == other.gender &&
          medicalHistory == other.medicalHistory &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      uid.hashCode ^
      name.hashCode ^
      email.hashCode ^
      role.hashCode ^
      avatarUrl.hashCode ^
      diseaseFocus.hashCode ^
      assignedDoctorId.hashCode ^
      phone.hashCode ^
      age.hashCode ^
      gender.hashCode ^
      medicalHistory.hashCode ^
      createdAt.hashCode;

  // Helper methods
  bool get isPatient => role == UserRole.patient;
  bool get isDoctor => role == UserRole.doctor;
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
  bool get hasDiseaseFocus => diseaseFocus != null && diseaseFocus!.isNotEmpty;
  bool get hasAssignedDoctor =>
      assignedDoctorId != null && assignedDoctorId!.isNotEmpty;
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  // Get disease focus as enum
  DiseaseFocus? get diseaseFocusEnum => DiseaseFocus.fromString(diseaseFocus);
}

// Enum cho vai trò người dùng
enum UserRole {
  patient('patient'),
  doctor('doctor');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'patient':
        return UserRole.patient;
      case 'doctor':
        return UserRole.doctor;
      default:
        throw ArgumentError('Invalid user role: $value');
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.patient:
        return 'Bệnh nhân';
      case UserRole.doctor:
        return 'Bác sĩ';
    }
  }
}

// Enum cho các chuyên khoa (disease focus) - chỉ 3 loại
enum DiseaseFocus {
  stress('stress', 'Stress'),
  cardiology('cardiology', 'Tim mạch'),
  diagnosis('diagnosis', 'Chuẩn đoán bệnh');

  const DiseaseFocus(this.value, this.displayName);
  final String value;
  final String displayName;

  static DiseaseFocus? fromString(String? value) {
    if (value == null || value.isEmpty) return null;

    for (DiseaseFocus focus in DiseaseFocus.values) {
      if (focus.value == value.toLowerCase()) {
        return focus;
      }
    }
    return null;
  }

  static List<DiseaseFocus> get allFocuses => DiseaseFocus.values;

  // Convert to Specialty enum (for doctor model compatibility)
  Specialty toSpecialty() {
    switch (this) {
      case DiseaseFocus.stress:
        return Specialty.stress;
      case DiseaseFocus.cardiology:
        return Specialty.cardiology;
      case DiseaseFocus.diagnosis:
        return Specialty.diagnosis;
    }
  }
}
