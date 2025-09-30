import 'package:flutter/material.dart';
import '../components/dialog/index.dart';

class UIHelper {
  /// Show error dialog
  static Future<void> showError({
    required BuildContext context,
    required String message,
    String? title,
    VoidCallback? onPressed,
  }) {
    return CustomDialog.showError(
      context: context,
      title: title ?? 'Lỗi',
      message: message,
      onPressed: onPressed,
    );
  }

  /// Show success dialog
  static Future<void> showSuccess({
    required BuildContext context,
    required String message,
    String? title,
    VoidCallback? onPressed,
  }) {
    return CustomDialog.showSuccess(
      context: context,
      title: title ?? 'Thành công',
      message: message,
      onPressed: onPressed,
    );
  }

  /// Show info dialog
  static Future<void> showInfo({
    required BuildContext context,
    required String message,
    String? title,
    VoidCallback? onPressed,
  }) {
    return CustomDialog.showInfo(
      context: context,
      title: title ?? 'Thông báo',
      message: message,
      onPressed: onPressed,
    );
  }

  /// Show confirmation dialog
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String message,
    String? title,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return CustomDialog.showConfirmation(
      context: context,
      title: title ?? 'Xác nhận',
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      onConfirm: onConfirm,
      onCancel: onCancel,
    );
  }

  /// Show loading dialog
  static Future<void> showLoading({
    required BuildContext context,
    String? message,
  }) {
    return CustomDialog.showLoading(
      context: context,
      message: message,
    );
  }

  /// Hide loading dialog
  static void hideLoading(BuildContext context) {
    CustomDialog.hideLoading(context);
  }

  /// Show snackbar
  static void showSnackBar({
    required BuildContext context,
    required String message,
    bool isError = false,
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}