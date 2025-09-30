import 'dart:math';
import '../models/user_model.dart';
import '../models/doctor_model.dart';
import 'user_service.dart';

/// Service để gán bác sĩ cho bệnh nhân dựa trên loại bệnh
class PatientDoctorAssignmentService {
  final UserService _userService = UserService();
  final Random _random = Random();

  /// Gán bác sĩ cho bệnh nhân dựa trên disease focus
  Future<String?> assignDoctorToPatient({
    required String patientId,
    required DiseaseFocus diseaseFocus,
  }) async {
    try {
      // Lấy danh sách bác sĩ có chuyên khoa tương ứng
      final doctors = await _userService.getUsersByRole(UserRole.doctor);
      
      // Lọc bác sĩ theo specialty
      final doctorModels = <DoctorModel>[];
      for (final user in doctors) {
        final doctor = DoctorModel.fromUserModel(user);
        if (doctor.specialty == diseaseFocus.toSpecialty()) {
          doctorModels.add(doctor);
        }
      }

      if (doctorModels.isEmpty) {
        // Log: Không tìm thấy bác sĩ chuyên khoa
        return null;
      }

      // Chọn bác sĩ có ít bệnh nhân nhất, hoặc random nếu bằng nhau
      final doctorWithPatientCounts = <Map<String, dynamic>>[];
      
      for (final doctor in doctorModels) {
        final patientCount = await _getPatientCountForDoctor(doctor.uid);
        doctorWithPatientCounts.add({
          'doctorId': doctor.uid,
          'patientCount': patientCount,
        });
      }

      // Sắp xếp theo số lượng bệnh nhân tăng dần
      doctorWithPatientCounts.sort((a, b) => 
        (a['patientCount'] as int).compareTo(b['patientCount'] as int));

      // Lấy những bác sĩ có ít bệnh nhân nhất
      final minPatientCount = doctorWithPatientCounts.first['patientCount'] as int;
      final availableDoctors = doctorWithPatientCounts
          .where((d) => d['patientCount'] == minPatientCount)
          .toList();

      // Chọn random một bác sĩ từ danh sách có ít bệnh nhân nhất
      final selectedDoctor = availableDoctors[
        _random.nextInt(availableDoctors.length)
      ];
      final selectedDoctorId = selectedDoctor['doctorId'] as String;

      // Cập nhật assignedDoctorId cho bệnh nhân
      final patient = await _userService.getUserById(patientId);
      if (patient != null) {
        final updatedPatient = patient.copyWith(
          assignedDoctorId: selectedDoctorId,
        );
        await _userService.updateUser(updatedPatient);
      }

      // Log: Đã gán bác sĩ cho bệnh nhân
      return selectedDoctorId;
      
    } catch (e) {
      // Log: Lỗi khi gán bác sĩ
      return null;
    }
  }

  /// Đếm số lượng bệnh nhân được gán cho một bác sĩ
  Future<int> _getPatientCountForDoctor(String doctorId) async {
    try {
      final patients = await _userService.getUsersByRole(UserRole.patient);
      return patients
          .where((patient) => patient.assignedDoctorId == doctorId)
          .length;
    } catch (e) {
      // Log: Lỗi khi đếm bệnh nhân của bác sĩ
      return 0;
    }
  }

  /// Lấy danh sách bệnh nhân của một bác sĩ
  Future<List<UserModel>> getPatientsForDoctor(String doctorId) async {
    try {
      final patients = await _userService.getUsersByRole(UserRole.patient);
      return patients
          .where((patient) => patient.assignedDoctorId == doctorId)
          .toList();
    } catch (e) {
      // Log: Lỗi khi lấy danh sách bệnh nhân của bác sĩ
      return [];
    }
  }

  /// Lấy thông tin bác sĩ được gán cho bệnh nhân
  Future<DoctorModel?> getAssignedDoctorForPatient(String patientId) async {
    try {
      final patient = await _userService.getUserById(patientId);
      if (patient?.assignedDoctorId == null) {
        return null;
      }

      final doctorUser = await _userService.getUserById(patient!.assignedDoctorId!);
      if (doctorUser == null || !doctorUser.isDoctor) {
        return null;
      }

      return DoctorModel.fromUserModel(doctorUser);
    } catch (e) {
      // Log: Lỗi khi lấy thông tin bác sĩ được gán
      return null;
    }
  }

  /// Hủy gán bác sĩ cho bệnh nhân
  Future<bool> unassignDoctorFromPatient(String patientId) async {
    try {
      final patient = await _userService.getUserById(patientId);
      if (patient != null) {
        final updatedPatient = patient.copyWith(
          assignedDoctorId: null,
        );
        await _userService.updateUser(updatedPatient);
        return true;
      }
      return false;
    } catch (e) {
      // Log: Lỗi khi hủy gán bác sĩ
      return false;
    }
  }

  /// Thống kê phân bố bệnh nhân theo bác sĩ
  Future<Map<String, int>> getDoctorPatientDistribution() async {
    try {
      final doctors = await _userService.getUsersByRole(UserRole.doctor);
      final distribution = <String, int>{};

      for (final doctor in doctors) {
        final patientCount = await _getPatientCountForDoctor(doctor.uid);
        distribution[doctor.name] = patientCount;
      }

      return distribution;
    } catch (e) {
      // Log: Lỗi khi lấy thống kê phân bố
      return {};
    }
  }
}