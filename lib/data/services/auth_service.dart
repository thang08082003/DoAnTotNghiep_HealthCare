import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthcare/data/services/user_service.dart';
import 'package:healthcare/data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Lấy user hiện tại
  User? get currentUser => _auth.currentUser;

  // Stream để lắng nghe thay đổi trạng thái auth
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng ký với email và password
  Future<UserCredential?> registerWithEmailAndPassword(
      String email, String password, {String? name, UserRole? role}) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Tạo user profile trong Firestore
      if (result.user != null) {
        await _userService.createUser(
          uid: result.user!.uid,
          name: name ?? 'Người dùng',
          email: email.trim(),
          role: role ?? UserRole.patient,
        );
      }
      
      return result;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Đã xảy ra lỗi không xác định';
    }
  }

  // Đăng nhập với email và password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Đã xảy ra lỗi không xác định';
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Không thể đăng xuất';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Không thể gửi email reset password';
    }
  }

  // Lấy thông tin user hiện tại từ Firestore
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      return await _userService.getCurrentUser();
    } catch (e) {
      return null;
    }
  }

  // Stream user profile
  Stream<UserModel?> get userProfileStream => _userService.currentUserStream;

  // Gửi email reset password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Đã xảy ra lỗi không xác định';
    }
  }

  // Kiểm tra user đã verify email chưa
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Gửi email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Đã xảy ra lỗi không xác định';
    }
  }

  // Reload user data
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      throw 'Không thể tải lại thông tin người dùng';
    }
  }

  // Xử lý thông báo lỗi
  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này';
      case 'wrong-password':
        return 'Mật khẩu không đúng';
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu, vui lòng thử lại sau';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được kích hoạt';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng';
      case 'weak-password':
        return 'Mật khẩu quá yếu';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng';
      case 'invalid-credential':
        return 'Thông tin đăng nhập không hợp lệ';
      default:
        return 'Đã xảy ra lỗi: $errorCode';
    }
  }
}