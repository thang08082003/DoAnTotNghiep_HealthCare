import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';

class AuthRepository {
  final AuthService _authService = AuthService();

  // Stream để lắng nghe thay đổi trạng thái auth
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  // Lấy user hiện tại
  User? get currentUser => _authService.currentUser;
  String? get currentEmail => _authService.currentUser?.email;

  // Đăng ký với email và password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _authService.registerWithEmailAndPassword(email, password);
  }

  // Đăng nhập với email và password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _authService.signInWithEmailAndPassword(email, password);
  }

  // Đăng xuất
  Future<void> signOut() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      await SessionService.clearSession(uid);
    }
    await _authService.signOut();
  }

  // Gửi email reset password
  Future<void> sendPasswordResetEmail(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  // Kiểm tra user đã verify email chưa
  bool get isEmailVerified => _authService.isEmailVerified;

  // Gửi email verification
  Future<void> sendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  // Reload user data
  Future<void> reloadUser() async {
    await _authService.reloadUser();
  }

  // Re-authenticate before sensitive operations
  Future<void> reauthenticateWithPassword(
    String email,
    String currentPassword,
  ) async {
    await _authService.reauthenticateWithPassword(
      email: email,
      currentPassword: currentPassword,
    );
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    await _authService.updatePassword(newPassword);
  }
}
