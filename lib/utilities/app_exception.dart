/// Base exception class for the application
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(this.message, {this.code, this.originalError, this.stackTrace});

  @override
  String toString() {
    if (code != null) {
      return 'AppException [$code]: $message';
    }
    return 'AppException: $message';
  }
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory NetworkException.noConnection() {
    return NetworkException(
      'Không có kết nối mạng. Vui lòng kiểm tra kết nối internet.',
      code: 'NO_CONNECTION',
    );
  }

  factory NetworkException.timeout() {
    return NetworkException(
      'Kết nối quá chậm. Vui lòng thử lại.',
      code: 'TIMEOUT',
    );
  }

  factory NetworkException.serverError() {
    return NetworkException(
      'Lỗi kết nối máy chủ. Vui lòng thử lại sau.',
      code: 'SERVER_ERROR',
    );
  }
}

/// Firebase/Firestore related exceptions
class FirestoreException extends AppException {
  FirestoreException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory FirestoreException.fromFirebase(dynamic error) {
    if (error == null) {
      return FirestoreException(
        'Lỗi cơ sở dữ liệu không xác định',
        code: 'UNKNOWN',
      );
    }

    // Handle Firebase exceptions
    final String errorMessage = error.toString().toLowerCase();

    if (errorMessage.contains('permission') ||
        errorMessage.contains('unauthorized')) {
      return FirestoreException(
        'Bạn không có quyền truy cập dữ liệu này',
        code: 'PERMISSION_DENIED',
        originalError: error,
      );
    }

    if (errorMessage.contains('not-found') ||
        errorMessage.contains('notfound')) {
      return FirestoreException(
        'Không tìm thấy dữ liệu',
        code: 'NOT_FOUND',
        originalError: error,
      );
    }

    if (errorMessage.contains('already-exists')) {
      return FirestoreException(
        'Dữ liệu đã tồn tại',
        code: 'ALREADY_EXISTS',
        originalError: error,
      );
    }

    if (errorMessage.contains('unavailable')) {
      return FirestoreException(
        'Dịch vụ tạm thời không khả dụng. Vui lòng thử lại.',
        code: 'UNAVAILABLE',
        originalError: error,
      );
    }

    return FirestoreException(
      'Lỗi kết nối cơ sở dữ liệu: ${error.toString()}',
      code: 'FIRESTORE_ERROR',
      originalError: error,
    );
  }
}

/// Authentication related exceptions
class AuthException extends AppException {
  AuthException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory AuthException.userNotFound() {
    return AuthException(
      'Không tìm thấy tài khoản với email này',
      code: 'USER_NOT_FOUND',
    );
  }

  factory AuthException.wrongPassword() {
    return AuthException('Mật khẩu không đúng', code: 'WRONG_PASSWORD');
  }

  factory AuthException.invalidEmail() {
    return AuthException('Email không hợp lệ', code: 'INVALID_EMAIL');
  }

  factory AuthException.emailAlreadyInUse() {
    return AuthException(
      'Email này đã được sử dụng',
      code: 'EMAIL_ALREADY_IN_USE',
    );
  }

  factory AuthException.weakPassword() {
    return AuthException(
      'Mật khẩu quá yếu. Vui lòng chọn mật khẩu mạnh hơn.',
      code: 'WEAK_PASSWORD',
    );
  }

  factory AuthException.userDisabled() {
    return AuthException('Tài khoản đã bị vô hiệu hóa', code: 'USER_DISABLED');
  }

  factory AuthException.tooManyRequests() {
    return AuthException(
      'Quá nhiều yêu cầu. Vui lòng thử lại sau.',
      code: 'TOO_MANY_REQUESTS',
    );
  }

  factory AuthException.invalidCredential() {
    return AuthException(
      'Thông tin đăng nhập không hợp lệ',
      code: 'INVALID_CREDENTIAL',
    );
  }
}

/// Validation related exceptions
class ValidationException extends AppException {
  ValidationException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ValidationException.required(String fieldName) {
    return ValidationException(
      '$fieldName là bắt buộc',
      code: 'REQUIRED_FIELD',
    );
  }

  factory ValidationException.invalidFormat(String fieldName) {
    return ValidationException(
      '$fieldName không đúng định dạng',
      code: 'INVALID_FORMAT',
    );
  }

  factory ValidationException.outOfRange(String fieldName) {
    return ValidationException(
      '$fieldName nằm ngoài phạm vi cho phép',
      code: 'OUT_OF_RANGE',
    );
  }
}

/// Storage/Media upload related exceptions
class StorageException extends AppException {
  StorageException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory StorageException.uploadFailed() {
    return StorageException(
      'Tải lên thất bại. Vui lòng thử lại.',
      code: 'UPLOAD_FAILED',
    );
  }

  factory StorageException.fileTooLarge() {
    return StorageException(
      'File quá lớn. Vui lòng chọn file nhỏ hơn.',
      code: 'FILE_TOO_LARGE',
    );
  }

  factory StorageException.unsupportedFileType() {
    return StorageException(
      'Định dạng file không được hỗ trợ',
      code: 'UNSUPPORTED_FILE_TYPE',
    );
  }
}

/// Health data related exceptions
class HealthDataException extends AppException {
  HealthDataException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory HealthDataException.permissionDenied() {
    return HealthDataException(
      'Bạn chưa cấp quyền truy cập dữ liệu sức khỏe',
      code: 'PERMISSION_DENIED',
    );
  }

  factory HealthDataException.notSupported() {
    return HealthDataException(
      'Thiết bị không hỗ trợ tính năng này',
      code: 'NOT_SUPPORTED',
    );
  }

  factory HealthDataException.dataNotAvailable() {
    return HealthDataException(
      'Không có dữ liệu sức khỏe trong khoảng thời gian này',
      code: 'DATA_NOT_AVAILABLE',
    );
  }
}
