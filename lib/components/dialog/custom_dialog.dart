import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/resources/gene/app_text_styles.dart';
import '../../data/resources/gene/app_dimensions.dart';
import '../buttons/primary_button.dart';

class CustomDialog {
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusLarge,
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.primaryColor,
              size: AppDimensions.iconLarge,
            ),
            SizedBox(width: AppDimensions.spacingMedium),
            Expanded(child: Text(title, style: AppTextStyles.heading3)),
          ],
        ),
        content: Text(message, style: AppTextStyles.body1Secondary),
        actions: [
          PrimaryButton(
            text: buttonText ?? 'OK',
            onPressed: () {
              Navigator.of(context).pop();
              onPressed?.call();
            },
            width: 100,
            height: AppDimensions.buttonHeightSmall,
          ),
        ],
      ),
    );
  }

  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusLarge,
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: AppDimensions.iconLarge,
            ),
            SizedBox(width: AppDimensions.spacingMedium),
            Expanded(child: Text(title, style: AppTextStyles.heading3)),
          ],
        ),
        content: Text(message, style: AppTextStyles.body1Secondary),
        actions: [
          PrimaryButton(
            text: buttonText ?? 'OK',
            onPressed: () {
              Navigator.of(context).pop();
              onPressed?.call();
            },
            width: 100,
            height: AppDimensions.buttonHeightSmall,
            backgroundColor: AppColors.error,
          ),
        ],
      ),
    );
  }

  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusLarge,
        ),
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: AppDimensions.iconLarge,
            ),
            SizedBox(width: AppDimensions.spacingMedium),
            Expanded(child: Text(title, style: AppTextStyles.heading3)),
          ],
        ),
        content: Text(message, style: AppTextStyles.body1Secondary),
        actions: [
          PrimaryButton(
            text: buttonText ?? 'OK',
            onPressed: () {
              Navigator.of(context).pop();
              onPressed?.call();
            },
            width: 100,
            height: AppDimensions.buttonHeightSmall,
            backgroundColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusLarge,
        ),
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: AppColors.warning,
              size: AppDimensions.iconLarge,
            ),
            SizedBox(width: AppDimensions.spacingMedium),
            Expanded(child: Text(title, style: AppTextStyles.heading3)),
          ],
        ),
        content: Text(message, style: AppTextStyles.body1Secondary),
        actions: [
          SecondaryButton(
            text: cancelText ?? 'Hủy',
            onPressed: () {
              Navigator.of(context).pop(false);
              onCancel?.call();
            },
            width: 80,
            height: AppDimensions.buttonHeightSmall,
          ),
          SizedBox(width: AppDimensions.spacingMedium),
          PrimaryButton(
            text: confirmText ?? 'Xác nhận',
            onPressed: () {
              Navigator.of(context).pop(true);
              onConfirm?.call();
            },
            width: 100,
            height: AppDimensions.buttonHeightSmall,
          ),
        ],
      ),
    );
  }

  static Future<void> showLoading({
    required BuildContext context,
    String? message,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusLarge,
        ),
        content: Padding(
          padding: AppDimensions.paddingAllMedium,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: AppDimensions.spacingMedium),
              Text(
                message ?? 'Đang xử lý...',
                style: AppTextStyles.body1Secondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }
}

class CustomBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool isDismissible = true,
    Color? backgroundColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor ?? Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppDimensions.radiusXLarge),
            topRight: Radius.circular(AppDimensions.radiusXLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(
                top: AppDimensions.spacingMedium,
                bottom: AppDimensions.spacingSmall,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
