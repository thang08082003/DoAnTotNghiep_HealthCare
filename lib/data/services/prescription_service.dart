import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medication_prescription_model.dart';

final prescriptionServiceProvider = Provider<PrescriptionService>((ref) {
  return PrescriptionService(FirebaseFirestore.instance);
});

class PrescriptionService {
  final FirebaseFirestore _firestore;

  PrescriptionService(this._firestore);

  /// Collection reference
  CollectionReference get _prescriptionsRef =>
      _firestore.collection('medication_prescriptions');

  /// Create a new prescription
  Future<String> createPrescription(MedicationPrescription prescription) async {
    final docRef = await _prescriptionsRef.add(prescription.toFirestore());
    return docRef.id;
  }

  /// Get prescriptions for a patient
  Stream<List<MedicationPrescription>> getPrescriptionsForPatient(
    String patientId,
  ) {
    return _prescriptionsRef
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationPrescription.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get prescriptions created by a doctor
  Stream<List<MedicationPrescription>> getPrescriptionsByDoctor(
    String doctorId,
  ) {
    return _prescriptionsRef
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationPrescription.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get prescriptions for a patient from a specific doctor
  Stream<List<MedicationPrescription>> getPrescriptionsForPatientByDoctor(
    String patientId,
    String doctorId,
  ) {
    return _prescriptionsRef
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationPrescription.fromFirestore(doc))
              .toList(),
        );
  }

  /// Update prescription status (patient response)
  Future<void> updatePrescriptionStatus({
    required String prescriptionId,
    required PrescriptionStatus status,
    String? patientResponse,
    int? modificationRequestCount,
    bool? requiresVideoCall,
  }) async {
    final updates = {
      'status': status.value,
      'patientResponse': patientResponse,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (modificationRequestCount != null) {
      updates['modificationRequestCount'] = modificationRequestCount;
    }

    if (requiresVideoCall != null) {
      updates['requiresVideoCall'] = requiresVideoCall;
    }

    await _prescriptionsRef.doc(prescriptionId).update(updates);
  }

  /// Update prescription details
  Future<void> updatePrescription(
    String prescriptionId,
    Map<String, dynamic> data,
  ) async {
    await _prescriptionsRef.doc(prescriptionId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete prescription
  Future<void> deletePrescription(String prescriptionId) async {
    await _prescriptionsRef.doc(prescriptionId).delete();
  }

  /// Get prescription by ID
  Future<MedicationPrescription?> getPrescriptionById(
    String prescriptionId,
  ) async {
    final doc = await _prescriptionsRef.doc(prescriptionId).get();
    if (!doc.exists) return null;
    return MedicationPrescription.fromFirestore(doc);
  }

  /// Get pending prescriptions for patient (need confirmation)
  Stream<List<MedicationPrescription>> getPendingPrescriptionsForPatient(
    String patientId,
  ) {
    return _prescriptionsRef
        .where('patientId', isEqualTo: patientId)
        .where(
          'status',
          isEqualTo: PrescriptionStatus.pendingPatientReview.value,
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationPrescription.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get active prescriptions for patient
  Stream<List<MedicationPrescription>> getActivePrescriptionsForPatient(
    String patientId,
  ) {
    return _prescriptionsRef
        .where('patientId', isEqualTo: patientId)
        .where(
          'status',
          whereIn: [
            PrescriptionStatus.approvedByPatient.value,
            PrescriptionStatus.active.value,
          ],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationPrescription.fromFirestore(doc))
              .toList(),
        );
  }

  /// Check and update expired prescriptions
  Future<void> updateExpiredPrescriptions() async {
    final snapshot = await _prescriptionsRef
        .where(
          'status',
          whereIn: [
            PrescriptionStatus.approvedByPatient.value,
            PrescriptionStatus.active.value,
          ],
        )
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      final prescription = MedicationPrescription.fromFirestore(doc);
      if (prescription.isExpired()) {
        batch.update(doc.reference, {
          'status': PrescriptionStatus.expired.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }
}
