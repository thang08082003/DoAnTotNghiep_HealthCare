import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_model.dart';

class DoctorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'doctors';

  // Create a new doctor profile
  static Future<void> createDoctor(DoctorModel doctor) async {
    try {
      await _firestore.collection(_collection).doc(doctor.uid).set(doctor.toJson());
    } catch (e) {
      throw Exception('Lỗi khi tạo hồ sơ bác sĩ: $e');
    }
  }

  // Get doctor by ID
  static Future<DoctorModel?> getDoctorById(String doctorId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(doctorId).get();
      
      if (doc.exists) {
        return DoctorModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Lỗi khi lấy thông tin bác sĩ: $e');
    }
  }

  // Update doctor profile
  static Future<void> updateDoctor(DoctorModel doctor) async {
    try {
      await _firestore.collection(_collection).doc(doctor.uid).update(
        doctor.toJson(),
      );
    } catch (e) {
      throw Exception('Lỗi khi cập nhật hồ sơ bác sĩ: $e');
    }
  }

  // Delete doctor
  static Future<void> deleteDoctor(String doctorId) async {
    try {
      await _firestore.collection(_collection).doc(doctorId).delete();
    } catch (e) {
      throw Exception('Lỗi khi xóa hồ sơ bác sĩ: $e');
    }
  }

  // Get all doctors
  static Future<List<DoctorModel>> getAllDoctors() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection(_collection)
          .where('role', isEqualTo: 'doctor')
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => DoctorModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi lấy danh sách bác sĩ: $e');
    }
  }

  // Get doctors by specialty
  static Future<List<DoctorModel>> getDoctorsBySpecialty(Specialty specialty) async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection(_collection)
          .where('specialty', isEqualTo: specialty.englishName)
          .where('role', isEqualTo: 'doctor')
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => DoctorModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi lấy danh sách bác sĩ theo chuyên khoa: $e');
    }
  }

  // Search doctors by name
  static Future<List<DoctorModel>> searchDoctorsByName(String name) async {
    try {
      String searchLower = name.toLowerCase();
      QuerySnapshot querySnapshot = await _firestore.collection(_collection)
          .where('role', isEqualTo: 'doctor')
          .get();

      return querySnapshot.docs
          .map((doc) => DoctorModel.fromJson(doc.data() as Map<String, dynamic>))
          .where((doctor) => doctor.name.toLowerCase().contains(searchLower))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi tìm kiếm bác sĩ: $e');
    }
  }

  // Stream for real-time doctor updates
  static Stream<List<DoctorModel>> getDoctorsStream() {
    return _firestore.collection(_collection)
        .where('role', isEqualTo: 'doctor')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DoctorModel.fromJson(doc.data()))
            .toList());
  }

  // Stream for doctor by ID
  static Stream<DoctorModel?> getDoctorStreamById(String doctorId) {
    return _firestore.collection(_collection)
        .doc(doctorId)
        .snapshots()
        .map((doc) => doc.exists 
            ? DoctorModel.fromJson(doc.data()!) 
            : null);
  }
}