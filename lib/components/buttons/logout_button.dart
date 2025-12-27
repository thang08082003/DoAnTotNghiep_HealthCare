import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';

class LogoutButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? text;
  final bool iconOnly;
  final double size;

  const LogoutButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.text,
    this.iconOnly = false,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return SizedBox(
        width: size,
        height: size,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 2,
          ),
          child: isLoading
              ? SizedBox(
                  width: size * 0.5,
                  height: size * 0.5,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(Icons.logout, color: Colors.white, size: size * 0.5),
        ),
      );
    }

    return SizedBox(
      height: size,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(size / 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 2,
        ),
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.logout, color: Colors.white, size: 16),
        label: Text(
          text ?? 'Đăng xuất',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
