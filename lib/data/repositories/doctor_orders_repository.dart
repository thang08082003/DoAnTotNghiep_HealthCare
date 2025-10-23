import '../services/doctor_orders_service.dart';
import '../models/doctor_order.dart';

class DoctorOrdersRepository {
  final DoctorOrdersService _service;
  DoctorOrdersRepository({DoctorOrdersService? service})
    : _service = service ?? DoctorOrdersService();

  Stream<List<DoctorOrder>> watchOrders({
    required String patientId,
    required String doctorId,
  }) {
    return _service.watchOrders(patientId: patientId, doctorId: doctorId);
  }

  Future<void> createOrder({
    required String patientId,
    required String doctorId,
    required String title,
    String? notes,
  }) {
    return _service.createOrder(
      patientId: patientId,
      doctorId: doctorId,
      title: title,
      notes: notes,
    );
  }
}
