import '../services/follow_request_service.dart';

class FollowRequestRepository {
  Future<String?> getRequestStatus({
    required String patientId,
    required String doctorId,
  }) {
    return FollowRequestService.getRequestStatus(
      patientId: patientId,
      doctorId: doctorId,
    );
  }

  Future<List<String>> getAcceptedDoctorIdsForPatient(String patientId) {
    return FollowRequestService.getAcceptedDoctorIdsForPatient(patientId);
  }

  Future<List<String>> getAcceptedPatientIdsForDoctor(String doctorId) {
    return FollowRequestService.getAcceptedPatientIdsForDoctor(doctorId);
  }

  Future<void> acceptRequest({
    required String requestId,
    required String doctorId,
    required String patientId,
    String? doctorName,
  }) {
    return FollowRequestService.acceptRequest(
      requestId: requestId,
      doctorId: doctorId,
      patientId: patientId,
      doctorName: doctorName,
    );
  }

  Future<void> declineRequest({
    required String requestId,
    required String doctorId,
    required String patientId,
    String? doctorName,
  }) {
    return FollowRequestService.declineRequest(
      requestId: requestId,
      doctorId: doctorId,
      patientId: patientId,
      doctorName: doctorName,
    );
  }
}
