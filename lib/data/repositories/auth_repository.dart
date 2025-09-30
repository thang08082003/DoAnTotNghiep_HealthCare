import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService = AuthService();

  // Stream để lắng nghe thay đổi trạng thái auth
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  // Lấy user hiện tại
  User? get currentUser => _authService.currentUser;

  // Đăng ký với email và password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email, 
    String password
  ) async {
    return await _authService.registerWithEmailAndPassword(email, password);
  }

  // Đăng nhập với email và password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email, 
    String password
  ) async {
    return await _authService.signInWithEmailAndPassword(email, password);
  }

  // Đăng xuất
  Future<void> signOut() async {
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
}