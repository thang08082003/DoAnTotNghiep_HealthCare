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
  final List<String>? allergicMedications;
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
    this.allergicMedications,
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
      allergicMedications: json['allergicMedications'] != null
          ? List<String>.from(json['allergicMedications'] as List)
          : null,
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
      'allergicMedications': allergicMedications,
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
    List<String>? allergicMedications,
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
      allergicMedications: allergicMedications ?? this.allergicMedications,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel{uid: $uid, name: $name, email: $email, role: $role, avatarUrl: $avatarUrl, diseaseFocus: $diseaseFocus, assignedDoctorId: $assignedDoctorId, phone: $phone, age: $age, gender: $gender, medicalHistory: $medicalHistory, allergicMedications: $allergicMedications, createdAt: $createdAt}';
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
          _listEquals(allergicMedications, other.allergicMedications) &&
          createdAt == other.createdAt;

  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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
      allergicMedications.hashCode ^
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

// Enum cho các bệnh cần theo dõi - 10 loại bệnh thực tế
enum DiseaseFocus {
  diabetes('diabetes', 'Tiểu đường'),
  hypertension('hypertension', 'Cao huyết áp'),
  cardiology('cardiology', 'Tim mạch'),
  respiratory('respiratory', 'Hô hấp'),
  gastroenterology('gastroenterology', 'Tiêu hóa'),
  neurology('neurology', 'Thần kinh'),
  orthopedics('orthopedics', 'Cơ xương khớp'),
  dermatology('dermatology', 'Da liễu'),
  mentalHealth('mental_health', 'Sức khỏe tâm thần'),
  obesity('obesity', 'Béo phì');

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
      case DiseaseFocus.diabetes:
        return Specialty.diabetes;
      case DiseaseFocus.hypertension:
        return Specialty.hypertension;
      case DiseaseFocus.cardiology:
        return Specialty.cardiology;
      case DiseaseFocus.respiratory:
        return Specialty.respiratory;
      case DiseaseFocus.gastroenterology:
        return Specialty.gastroenterology;
      case DiseaseFocus.neurology:
        return Specialty.neurology;
      case DiseaseFocus.orthopedics:
        return Specialty.orthopedics;
      case DiseaseFocus.dermatology:
        return Specialty.dermatology;
      case DiseaseFocus.mentalHealth:
        return Specialty.mentalHealth;
      case DiseaseFocus.obesity:
        return Specialty.obesity;
    }
  }
}
