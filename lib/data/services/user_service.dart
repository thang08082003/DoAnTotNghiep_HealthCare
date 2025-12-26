import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthcare/data/models/user_model.dart';
import 'package:healthcare/data/models/doctor_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection name
  static const String _usersCollection = 'users';

  // Stream để lắng nghe thay đổi user hiện tại
  Stream<UserModel?> get currentUserStream {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return await getUserById(firebaseUser.uid);
    });
  }

  // Stream để lắng nghe thay đổi user theo ID
  Stream<UserModel?> watchUser(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;
      return UserModel.fromJson(snapshot.data()!);
    });
  }

  // Stream để lắng nghe thay đổi users theo role
  Stream<List<UserModel>> watchUsersByRole(UserRole role) {
    return _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: role.value)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromJson(doc.data()))
              .toList();
        });
  }

  // Tạo user mới trong Firestore
  Future<UserModel> createUser({
    required String uid,
    required String name,
    required String email,
    required UserRole role,
    String? avatarUrl,
    String? diseaseFocus,
    String? specialty,
    // Patient specific
    String? phone,
    int? age,
    String? gender,
    String? medicalHistory,
    List<String>? allergicMedications,
    // Doctor specific
    int? yearsExperience,
    String? description,
  }) async {
    try {
      UserModel userModel;

      if (role == UserRole.doctor && specialty != null) {
        // Tạo DoctorModel nếu là bác sĩ và có specialty
        final doctorSpecialty = Specialty.fromString(specialty);
        userModel = DoctorModel(
          uid: uid,
          name: name,
          email: email,
          specialty: doctorSpecialty,
          createdAt: DateTime.now(),
          avatarUrl: avatarUrl,
          yearsExperience: yearsExperience,
          phone: phone,
          age: age,
          gender: gender,
          medicalHistory: medicalHistory,
          description: description,
          // đảm bảo role được set chính xác trong json
        );
      } else {
        // Tạo UserModel thông thường cho patient hoặc doctor không có specialty
        userModel = UserModel(
          uid: uid,
          name: name,
          email: email,
          role: role,
          avatarUrl: avatarUrl,
          diseaseFocus: diseaseFocus,
          // Patient fields (if provided at onboarding)
          phone: phone,
          age: age,
          gender: gender,
          medicalHistory: medicalHistory,
          allergicMedications: allergicMedications,
          createdAt: DateTime.now(),
        );
      }

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set(userModel.toJson());

      return userModel;
    } catch (e) {
      throw Exception('Không thể tạo user: $e');
    }
  }

  // Lấy thông tin user theo ID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // Check if this is a doctor with specialty field
        if (data['role'] == 'doctor' && data['specialty'] != null) {
          return DoctorModel.fromJson(data);
        } else {
          return UserModel.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Không thể lấy thông tin user: $e');
    }
  }

  // Lấy raw document data theo ID (dành cho một số UI cần field tự do)
  Future<Map<String, dynamic>?> getUserRawById(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      return doc.data();
    } catch (e) {
      throw Exception('Không thể lấy raw user: $e');
    }
  }

  // Cập nhật thông tin user
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update(user.toJson());
    } catch (e) {
      throw Exception('Không thể cập nhật user: $e');
    }
  }

  // Cập nhật một số field cụ thể
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update(fields);
    } catch (e) {
      throw Exception('Không thể cập nhật thông tin: $e');
    }
  }

  // Cập nhật tên
  Future<void> updateUserName(String uid, String name) async {
    await updateUserFields(uid, {'name': name});
  }

  // Cập nhật avatar
  Future<void> updateUserAvatar(String uid, String avatarUrl) async {
    await updateUserFields(uid, {'avatarUrl': avatarUrl});
  }

  // Cập nhật chuyên khoa (cho bác sĩ) hoặc bệnh quan tâm (cho bệnh nhân)
  Future<void> updateDiseaseFocus(String uid, String? diseaseFocus) async {
    await updateUserFields(uid, {'diseaseFocus': diseaseFocus});
  }

  // Lấy danh sách bác sĩ theo chuyên khoa
  Future<List<UserModel>> getDoctorsByFocus(String diseaseFocus) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: 'doctor')
          .where('diseaseFocus', isEqualTo: diseaseFocus)
          .get();

      return query.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
    } catch (e) {
      throw Exception('Không thể lấy danh sách bác sĩ: $e');
    }
  }

  // Lấy users theo role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: role.value)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();

        // Return appropriate model based on role and data
        if (role == UserRole.doctor && data['specialty'] != null) {
          return DoctorModel.fromJson(data);
        } else {
          return UserModel.fromJson(data);
        }
      }).toList();
    } catch (e) {
      throw Exception(
        'Không thể lấy danh sách user với role ${role.value}: $e',
      );
    }
  }

  // Lấy tất cả bác sĩ
  Future<List<UserModel>> getAllDoctors() async {
    return await getUsersByRole(UserRole.doctor);
  }

  // Lấy tất cả bệnh nhân
  Future<List<UserModel>> getAllPatients() async {
    return await getUsersByRole(UserRole.patient);
  }

  // Tìm kiếm user theo tên
  Future<List<UserModel>> searchUsersByName(String name) async {
    try {
      // Firestore không hỗ trợ tìm kiếm text đầy đủ, nên dùng range query
      final query = await _firestore
          .collection(_usersCollection)
          .where('name', isGreaterThanOrEqualTo: name)
          .where('name', isLessThan: '${name}z')
          .get();

      return query.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
    } catch (e) {
      throw Exception('Không thể tìm kiếm user: $e');
    }
  }

  // Xóa user (chỉ xóa document, không xóa Firebase Auth)
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
    } catch (e) {
      throw Exception('Không thể xóa user: $e');
    }
  }

  // Kiểm tra user đã tồn tại chưa
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Lấy user hiện tại
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return await getUserById(firebaseUser.uid);
  }

  // Lấy tất cả users
  Future<List<UserModel>> getAllUsers() async {
    try {
      final query = await _firestore.collection(_usersCollection).get();

      return query.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
    } catch (e) {
      throw Exception('Không thể lấy danh sách user: $e');
    }
  }

  // Thống kê số lượng user theo role
  Future<Map<String, int>> getUserStats() async {
    try {
      final patientsQuery = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: 'patient')
          .get();

      final doctorsQuery = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: 'doctor')
          .get();

      return {
        'patients': patientsQuery.docs.length,
        'doctors': doctorsQuery.docs.length,
        'total': patientsQuery.docs.length + doctorsQuery.docs.length,
      };
    } catch (e) {
      throw Exception('Không thể lấy thống kê: ${e.toString()}');
    }
  }
}
