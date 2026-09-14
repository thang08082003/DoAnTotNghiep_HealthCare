import '../models/user_model.dart';
import '../services/user_service.dart';

class UserRepository {
  final UserService _userService = UserService();

  // Tạo user mới
  Future<void> createUser({
    required String uid,
    required String name,
    required String email,
    required UserRole role,
    String? diseaseFocus,
    String? specialty,
    // Patient
    String? phone,
    int? age,
    String? gender,
    String? medicalHistory,
    List<String>? allergicMedications,
    // Doctor
    int? yearsExperience,
    String? description,
  }) async {
    await _userService.createUser(
      uid: uid,
      name: name,
      email: email,
      role: role,
      diseaseFocus: diseaseFocus,
      specialty: specialty,
      phone: phone,
      age: age,
      gender: gender,
      medicalHistory: medicalHistory,
      allergicMedications: allergicMedications,
      yearsExperience: yearsExperience,
      description: description,
    );
  }

  // Lấy user theo ID
  Future<UserModel?> getUserById(String uid) async {
    return await _userService.getUserById(uid);
  }

  // Lấy raw user document (optional)
  Future<Map<String, dynamic>?> getUserRawById(String uid) async {
    return await _userService.getUserRawById(uid);
  }

  // Cập nhật user
  Future<void> updateUser(UserModel user) async {
    await _userService.updateUser(user);
  }

  // Xóa user
  Future<void> deleteUser(String uid) async {
    await _userService.deleteUser(uid);
  }

  // Kiểm tra user có tồn tại không
  Future<bool> userExists(String uid) async {
    return await _userService.userExists(uid);
  }

  // Lấy users theo role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    return await _userService.getUsersByRole(role);
  }

  // Lấy tất cả users
  Future<List<UserModel>> getAllUsers() async {
    return await _userService.getAllUsers();
  }

  // Stream để lắng nghe thay đổi user
  Stream<UserModel?> watchUser(String uid) {
    return _userService.watchUser(uid);
  }

  // Stream để lắng nghe thay đổi users theo role
  Stream<List<UserModel>> watchUsersByRole(UserRole role) {
    return _userService.watchUsersByRole(role);
  }
}
