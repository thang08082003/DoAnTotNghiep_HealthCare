import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_model.dart';
import '../services/user_service.dart';

class DoctorProfileRepository {
  final UserService _userService = UserService();

  Future<DoctorModel?> getDoctor(String uid) async {
    final user = await _userService.getUserById(uid);
    return user is DoctorModel ? user : null;
  }

  Future<Map<String, dynamic>?> getRaw(String uid) {
    return _userService.getUserRawById(uid);
  }

  Future<void> updateDoctorProfile(
    String uid, {
    required String name,
    Specialty? specialty,
    int? yearsExperience,
    String? description,
  }) async {
    final fields = <String, dynamic>{'name': name};
    if (specialty != null) {
      fields['specialty'] = specialty.englishName;
    }
    fields['yearsExperience'] = yearsExperience == null
        ? FieldValue.delete()
        : yearsExperience;
    fields['description'] = (description == null || description.trim().isEmpty)
        ? FieldValue.delete()
        : description.trim();
    await _userService.updateUserFields(uid, fields);
  }

  Future<void> updatePhone(String uid, String? phoneDigits) async {
    await _userService.updateUserFields(uid, {'phone': phoneDigits});
  }

  Future<void> updateYearsExperience(String uid, int years) async {
    await _userService.updateUserFields(uid, {'yearsExperience': years});
  }

  Future<void> updateDescription(String uid, String? description) async {
    await _userService.updateUserFields(uid, {
      'description': (description == null || description.trim().isEmpty)
          ? FieldValue.delete()
          : description.trim(),
    });
  }
}
