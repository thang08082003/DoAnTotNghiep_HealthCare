import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/resources/gene/app_text_styles.dart';
import '../../data/resources/gene/app_dimensions.dart';

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
          SizedBox(height: AppDimensions.spacingMedium),
          Text(
            message!,
            style: AppTextStyles.body2Secondary,
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
          elevation: AppDimensions.elevationHigh,
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMedium,
          ),
          child: Padding(
            padding: AppDimensions.paddingAllXLarge,
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
        padding: AppDimensions.paddingAllXLarge,
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
      padding: AppDimensions.paddingAllMedium,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: AppDimensions.iconMedium,
            height: AppDimensions.iconMedium,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppDimensions.spacingMedium),
          Text(
            message ?? 'Đang làm mới...',
            style: AppTextStyles.body2Secondary,
          ),
        ],
      ),
    );
  }
}
