import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/medication_prescription_model.dart';
import '../../data/services/prescription_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/models/notification_model.dart';
import '../../providers/user_provider.dart';

final prescriptionViewModelProvider =
    ChangeNotifierProvider.autoDispose<PrescriptionViewModel>(
      (ref) => PrescriptionViewModel(
        prescriptionService: ref.watch(prescriptionServiceProvider),
        ref: ref,
      ),
    );

class PrescriptionViewModel extends ChangeNotifier {
  final PrescriptionService prescriptionService;
  final Ref ref;

  PrescriptionViewModel({required this.prescriptionService, required this.ref});

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _error;
  String? get error => _error;

  /// Create new prescription
  Future<bool> createPrescription({
    required String patientId,
    required String medicationName,
    String? concentration,
    String? quantity,
    required String dosage,
    required String route,
    String? timing,
    String? specialInstructions,
    required DateTime startDate,
    required int durationDays,
    required int renewalWindowDays,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      final endDate = startDate.add(Duration(days: durationDays));

      final prescription = MedicationPrescription(
        id: '',
        patientId: patientId,
        doctorId: currentUser.uid,
        doctorName: currentUser.name,
        medicationName: medicationName,
        concentration: concentration?.trim().isEmpty ?? true
            ? null
            : concentration,
        quantity: quantity?.trim().isEmpty ?? true ? null : quantity,
        dosage: dosage,
        route: route,
        timing: timing?.trim().isEmpty ?? true ? null : timing,
        specialInstructions: specialInstructions?.trim().isEmpty ?? true
            ? null
            : specialInstructions,
        startDate: startDate,
        durationDays: durationDays,
        endDate: endDate,
        renewalWindowDays: renewalWindowDays,
        createdAt: DateTime.now(),
      );

      await prescriptionService.createPrescription(prescription);

      // Send notification to patient
      await NotificationService.createNotification(
        toUserId: patientId,
        senderId: currentUser.uid,
        type: NotificationType.prescription,
        title: 'Chỉ định thuốc mới',
        body:
            'Bác sĩ ${currentUser.name} đã tạo chỉ định thuốc "$medicationName" cho bạn. Vui lòng xem và phản hồi.',
        data: {
          'medicationName': medicationName,
          'doctorId': currentUser.uid,
          'doctorName': currentUser.name,
        },
      );

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Update existing prescription (create new version)
  Future<bool> updatePrescription({
    required String prescriptionId,
    required String patientId,
    required String medicationName,
    String? concentration,
    String? quantity,
    required String dosage,
    required String route,
    String? timing,
    String? specialInstructions,
    required DateTime startDate,
    required int durationDays,
    required int renewalWindowDays,
    required double currentVersion,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      final endDate = startDate.add(Duration(days: durationDays));
      final newVersion = currentVersion + 0.1;

      final updates = {
        'medicationName': medicationName,
        'concentration': concentration?.trim().isEmpty ?? true
            ? null
            : concentration,
        'quantity': quantity?.trim().isEmpty ?? true ? null : quantity,
        'dosage': dosage,
        'route': route,
        'timing': timing?.trim().isEmpty ?? true ? null : timing,
        'specialInstructions': specialInstructions?.trim().isEmpty ?? true
            ? null
            : specialInstructions,
        'startDate': startDate,
        'durationDays': durationDays,
        'endDate': endDate,
        'renewalWindowDays': renewalWindowDays,
        'version': newVersion,
        'status': PrescriptionStatus.pendingPatientReview.value,
        'patientResponse': null, // Clear previous response
      };

      await prescriptionService.updatePrescription(prescriptionId, updates);

      // Send notification to patient about the update
      await NotificationService.createNotification(
        toUserId: patientId,
        senderId: currentUser.uid,
        type: NotificationType.prescription,
        title: 'Chỉ định thuốc đã cập nhật',
        body:
            'Bác sĩ ${currentUser.name} đã chỉnh sửa chỉ định thuốc "$medicationName". Vui lòng xem lại và phản hồi.',
        data: {
          'prescriptionId': prescriptionId,
          'medicationName': medicationName,
          'doctorId': currentUser.uid,
          'doctorName': currentUser.name,
          'version': newVersion.toString(),
        },
      );

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
