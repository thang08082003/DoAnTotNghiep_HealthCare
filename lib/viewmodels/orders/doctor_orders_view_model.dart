import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/doctor_orders_repository.dart';
import '../../data/models/doctor_order.dart';

class DoctorOrdersViewModel {
  final DoctorOrdersRepository _repo = DoctorOrdersRepository();

  Stream<List<DoctorOrder>> watchOrders({
    required String patientId,
    required String doctorId,
  }) {
    return _repo.watchOrders(patientId: patientId, doctorId: doctorId);
  }

  Future<void> createOrder({
    required String patientId,
    required String doctorId,
    required String title,
    String? notes,
  }) {
    return _repo.createOrder(
      patientId: patientId,
      doctorId: doctorId,
      title: title,
      notes: notes,
    );
  }
}

final doctorOrdersViewModelProvider = Provider<DoctorOrdersViewModel>((ref) {
  return DoctorOrdersViewModel();
});
