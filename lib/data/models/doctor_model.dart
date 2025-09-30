import 'user_model.dart';

enum Specialty {
  stress('Stress', 'Stress'),
  cardiology('Cardiology', 'Tim mạch'),
  diagnosis('Diagnosis', 'Chuẩn đoán bệnh');

  const Specialty(this.englishName, this.vietnameseName);

  final String englishName;
  final String vietnameseName;

  String get displayName => vietnameseName;

  static Specialty fromString(String specialty) {
    return Specialty.values.firstWhere(
      (s) => s.englishName.toLowerCase() == specialty.toLowerCase() ||
             s.vietnameseName.toLowerCase() == specialty.toLowerCase(),
      orElse: () => Specialty.stress,
    );
  }

  static List<Specialty> get allSpecialties => Specialty.values;

  DiseaseFocus toDiseaseFocus() {
    switch (this) {
      case Specialty.stress:
        return DiseaseFocus.stress;
      case Specialty.cardiology:
        return DiseaseFocus.cardiology;
      case Specialty.diagnosis:
        return DiseaseFocus.diagnosis;
    }
  }
}

class DoctorModel extends UserModel {
  final Specialty specialty;

  DoctorModel({
    required super.uid,
    required super.name,
    required super.email,
    super.avatarUrl,
    required super.createdAt,
    required this.specialty,
    super.diseaseFocus,
    super.assignedDoctorId,
  }) : super(role: UserRole.doctor);

  // Factory constructor from JSON
  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      specialty: Specialty.fromString(json['specialty'] ?? 'General Medicine'),
      diseaseFocus: json['diseaseFocus'],
    );
  }

  // Factory constructor from UserModel
  factory DoctorModel.fromUserModel(UserModel user) {
    // Map diseaseFocus to specialty
    Specialty mappedSpecialty = Specialty.stress; // default
    if (user.diseaseFocus != null) {
      final diseaseFocusEnum = DiseaseFocus.fromString(user.diseaseFocus!);
      if (diseaseFocusEnum != null) {
        mappedSpecialty = diseaseFocusEnum.toSpecialty();
      }
    }

    return DoctorModel(
      uid: user.uid,
      name: user.name,
      email: user.email,
      avatarUrl: user.avatarUrl,
      createdAt: user.createdAt,
      specialty: mappedSpecialty,
      diseaseFocus: user.diseaseFocus,
      assignedDoctorId: user.assignedDoctorId,
    );
  }

  // Convert to JSON
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['specialty'] = specialty.englishName;
    return json;
  }

  // CopyWith method for immutable updates
  @override
  DoctorModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? avatarUrl,
    String? diseaseFocus,
    String? assignedDoctorId,
    DateTime? createdAt,
    UserRole? role, // Keep this for compatibility
    Specialty? specialty,
  }) {
    return DoctorModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      specialty: specialty ?? this.specialty,
      diseaseFocus: diseaseFocus ?? this.diseaseFocus,
    );
  }

  // Validation methods
  @override
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  @override
  String toString() {
    return 'DoctorModel(uid: $uid, name: $name, specialty: ${specialty.vietnameseName})';
  }
}