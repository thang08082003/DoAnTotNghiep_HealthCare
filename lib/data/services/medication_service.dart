import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medication_model.dart';

/// Service để quản lý thuốc trên Firestore
class MedicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lấy danh sách thuốc của user
  Stream<List<Medication>> getMedications(String userId) {
    return _firestore
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .orderBy('isActive', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Medication.fromFirestore(doc))
              .toList(),
        );
  }

  // Lấy thuốc đang sử dụng
  Stream<List<Medication>> getActiveMedications(String userId) {
    return _firestore
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Medication.fromFirestore(doc))
              .toList(),
        );
  }

  // Thêm thuốc mới
  Future<void> addMedication({
    required String userId,
    required String name,
    String? dosage,
    String? frequency,
    String? instructions,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
  }) async {
    final medication = Medication(
      id: '',
      userId: userId,
      name: name,
      dosage: dosage,
      frequency: frequency,
      instructions: instructions,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('medications').add(medication.toFirestore());
  }

  // Cập nhật thuốc
  Future<void> updateMedication(
    String medicationId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore
        .collection('medications')
        .doc(medicationId)
        .update(updates);
  }

  // Đánh dấu ngưng sử dụng
  Future<void> deactivateMedication(String medicationId) async {
    await _firestore.collection('medications').doc(medicationId).update({
      'isActive': false,
    });
  }

  // Kích hoạt lại thuốc
  Future<void> activateMedication(String medicationId) async {
    await _firestore.collection('medications').doc(medicationId).update({
      'isActive': true,
    });
  }

  // Xóa thuốc
  Future<void> deleteMedication(String medicationId) async {
    await _firestore.collection('medications').doc(medicationId).delete();
  }
}

// Provider
final medicationServiceProvider = Provider<MedicationService>((ref) {
  return MedicationService();
});
