import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'app_exception.dart';

/// Centralized error handler for the application
class ErrorHandler {
  /// Convert any error to AppException with user-friendly message
  static AppException handle(dynamic error, [StackTrace? stackTrace]) {
    // Already an AppException - return as is
    if (error is AppException) {
      return error;
    }

    // Firebase Auth errors
    if (error is firebase_auth.FirebaseAuthException) {
      return _handleFirebaseAuthError(error, stackTrace);
    }

    // Firestore errors
    if (error is firestore.FirebaseException) {
      return FirestoreException.fromFirebase(error);
    }

    // Network errors (check error message)
    if (error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection')) {
      return NetworkException(
        'Lỗi kết nối mạng. Vui lòng kiểm tra internet.',
        code: 'NETWORK_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Timeout errors
    if (error.toString().toLowerCase().contains('timeout')) {
      return NetworkException.timeout();
    }

    // Generic error
    return AppException(
      'Đã xảy ra lỗi: ${error.toString()}',
      code: 'UNKNOWN_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Handle Firebase Auth specific errors
  static AuthException _handleFirebaseAuthError(
    firebase_auth.FirebaseAuthException error,
    StackTrace? stackTrace,
  ) {
    switch (error.code) {
      case 'user-not-found':
        return AuthException.userNotFound();
      case 'wrong-password':
        return AuthException.wrongPassword();
      case 'invalid-email':
        return AuthException.invalidEmail();
      case 'email-already-in-use':
        return AuthException.emailAlreadyInUse();
      case 'weak-password':
        return AuthException.weakPassword();
      case 'user-disabled':
        return AuthException.userDisabled();
      case 'too-many-requests':
        return AuthException.tooManyRequests();
      case 'invalid-credential':
        return AuthException.invalidCredential();
      case 'operation-not-allowed':
        return AuthException(
          'Phương thức đăng nhập này chưa được kích hoạt',
          code: 'OPERATION_NOT_ALLOWED',
        );
      case 'network-request-failed':
        return AuthException(
          'Lỗi kết nối mạng',
          code: 'NETWORK_REQUEST_FAILED',
        );
      default:
        return AuthException(
          error.message ?? 'Đã xảy ra lỗi xác thực',
          code: error.code,
          originalError: error,
          stackTrace: stackTrace,
        );
    }
  }

  /// Show error message to user via SnackBar
  static void showError(BuildContext context, dynamic error) {
    final appException = handle(error);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(appException.message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Đóng',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success message to user via SnackBar
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show info message to user via SnackBar
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Log error for debugging (can be extended with crashlytics/logging service)
  static void logError(dynamic error, [StackTrace? stackTrace]) {
    final appException = handle(error, stackTrace);

    // For now, just output to console in debug mode
    // TODO: Integrate with Firebase Crashlytics or logging service
    debugPrint('═══════════════════════════════════════════');
    debugPrint('ERROR: ${appException.code ?? 'UNKNOWN'}');
    debugPrint('Message: ${appException.message}');
    if (appException.originalError != null) {
      debugPrint('Original: ${appException.originalError}');
    }
    if (appException.stackTrace != null) {
      debugPrint('Stack trace:');
      debugPrint(appException.stackTrace.toString());
    }
    debugPrint('═══════════════════════════════════════════');
  }

  /// Check if error is network-related
  static bool isNetworkError(dynamic error) {
    final appException = handle(error);
    return appException is NetworkException;
  }

  /// Check if error is auth-related
  static bool isAuthError(dynamic error) {
    final appException = handle(error);
    return appException is AuthException;
  }

  /// Check if error is permission-related
  static bool isPermissionError(dynamic error) {
    final appException = handle(error);
    if (appException is FirestoreException) {
      return appException.code == 'PERMISSION_DENIED';
    }
    if (appException is HealthDataException) {
      return appException.code == 'PERMISSION_DENIED';
    }
    return false;
  }

  /// Get user-friendly error message
  static String getErrorMessage(dynamic error) {
    final appException = handle(error);
    return appException.message;
  }
}

/// Extension to easily handle errors in ViewModels
extension ErrorHandlerExtension on Object {
  /// Convert to AppException
  AppException toAppException([StackTrace? stackTrace]) {
    return ErrorHandler.handle(this, stackTrace);
  }

  /// Get user-friendly message
  String toErrorMessage() {
    return ErrorHandler.getErrorMessage(this);
  }
}
