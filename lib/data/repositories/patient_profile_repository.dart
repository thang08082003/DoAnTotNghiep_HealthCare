import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';

class PatientProfileRepository {
  final UserService _userService = UserService();

  Future<UserModel?> getPatient(String uid) {
    return _userService.getUserById(uid);
  }

  Future<Map<String, dynamic>?> getRaw(String uid) {
    return _userService.getUserRawById(uid);
  }

  Future<void> updatePatientProfile(
    String uid, {
    String? phone,
    int? age,
    String? gender,
    String? medicalHistory,
  }) async {
    final fields = <String, dynamic>{};
    if (phone != null) fields['phone'] = phone;
    if (gender != null) fields['gender'] = gender;
    if (medicalHistory != null) fields['medicalHistory'] = medicalHistory;
    fields['age'] = age ?? FieldValue.delete();
    await _userService.updateUserFields(uid, fields);
  }

  Future<void> updatePhone(String uid, String phone) {
    return _userService.updateUserFields(uid, {'phone': phone});
  }

  Future<void> updateAge(String uid, int? age) {
    return _userService.updateUserFields(uid, {
      'age': age ?? FieldValue.delete(),
    });
  }

  Future<void> updateMedicalHistory(String uid, String history) {
    return _userService.updateUserFields(uid, {'medicalHistory': history});
  }

  Future<void> updateDiseaseFocus(String uid, String? focusValue) {
    return _userService.updateUserFields(uid, {
      'diseaseFocus': (focusValue == null || focusValue.isEmpty)
          ? FieldValue.delete()
          : focusValue,
    });
  }

  Future<void> updateAllergicMedications(String uid, List<String> medications) {
    return _userService.updateUserFields(uid, {
      'allergicMedications': medications,
    });
  }
}
