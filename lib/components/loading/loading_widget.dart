import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;

  const LoadingWidget({super.key, this.message, this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            color: color ?? AppColors.primaryColor,
            strokeWidth: 2,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class FullScreenLoading extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;
  final Color? loadingColor;

  const FullScreenLoading({
    super.key,
    this.message,
    this.backgroundColor,
    this.loadingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.black54,
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LoadingWidget(
              message: message ?? 'Đang tải...',
              color: loadingColor,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

class ButtonLoading extends StatelessWidget {
  final Color? color;
  final double size;

  const ButtonLoading({super.key, this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        color: color ?? Colors.white,
        strokeWidth: 2,
      ),
    );
  }
}

class ListLoading extends StatelessWidget {
  final String? message;
  final Color? color;

  const ListLoading({super.key, this.message, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: LoadingWidget(
          message: message ?? 'Đang tải dữ liệu...',
          color: color,
          size: 28,
        ),
      ),
    );
  }
}

class RefreshLoading extends StatelessWidget {
  final String? message;

  const RefreshLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            message ?? 'Đang làm mới...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
