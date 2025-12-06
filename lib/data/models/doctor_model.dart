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
      (s) =>
          s.englishName.toLowerCase() == specialty.toLowerCase() ||
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
  final int? yearsExperience; // optional years of experience
  final String? description; // mô tả bác sĩ (bio)

  DoctorModel({
    required super.uid,
    required super.name,
    required super.email,
    super.avatarUrl,
    required super.createdAt,
    required this.specialty,
    this.yearsExperience,
    this.description,
    super.diseaseFocus,
    super.assignedDoctorId,
    super.phone,
    super.age,
    super.gender,
    super.medicalHistory,
  }) : super(role: UserRole.doctor);

  // Factory constructor from JSON
  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    // Parse specialty safely
    Specialty parsedSpecialty;
    final specialtyValue = json['specialty'];

    if (specialtyValue is String) {
      parsedSpecialty = Specialty.fromString(specialtyValue);
    } else if (specialtyValue is Specialty) {
      parsedSpecialty = specialtyValue;
    } else {
      // Default fallback
      parsedSpecialty = Specialty.stress;
    }

    return DoctorModel(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      specialty: parsedSpecialty,
      yearsExperience:
          (json['yearsExperience'] ??
                  json['experienceYears'] ??
                  json['experience'])
              as int?,
      description: json['description'],
      diseaseFocus: json['diseaseFocus'],
      phone: json['phone'],
      age: json['age'] is int
          ? json['age'] as int
          : (json['age'] is String ? int.tryParse(json['age']) : null),
      gender: json['gender'],
      medicalHistory: json['medicalHistory'],
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
      yearsExperience: null,
      description: null,
      diseaseFocus: user.diseaseFocus,
      assignedDoctorId: user.assignedDoctorId,
    );
  }

  // Convert to JSON
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['specialty'] = specialty.englishName;
    if (yearsExperience != null) json['yearsExperience'] = yearsExperience;
    if (description != null && description!.isNotEmpty) {
      json['description'] = description;
    }
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
    String? phone,
    int? age,
    String? gender,
    String? medicalHistory,
    DateTime? createdAt,
    UserRole? role, // Keep this for compatibility
    Specialty? specialty,
    int? yearsExperience,
    String? description,
  }) {
    return DoctorModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      specialty: specialty ?? this.specialty,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      description: description ?? this.description,
      diseaseFocus: diseaseFocus ?? this.diseaseFocus,
      assignedDoctorId: assignedDoctorId ?? this.assignedDoctorId,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      medicalHistory: medicalHistory ?? this.medicalHistory,
    );
  }

  // Validation methods
  @override
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  @override
  String toString() {
    return 'DoctorModel(uid: $uid, name: $name, specialty: ${specialty.vietnameseName}, yearsExperience: ${yearsExperience ?? 'n/a'}, description: ${description ?? ''})';
  }
}
