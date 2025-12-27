import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/resources/gene/app_text_styles.dart';
import '../../data/resources/gene/app_dimensions.dart';
import '../reviews/inline_user_avatar.dart';

class PatientCard extends StatelessWidget {
  final UserModel patient;
  final VoidCallback? onTap;
  final String? statusText; // e.g., "Đang theo dõi", "Đang chờ xác nhận"
  final Color? statusColor; // Color for status indicator
  final bool isPending; // true for pending requests
  final Future<void> Function()? onAccept; // Callback when accepting request
  final Future<void> Function()? onReject; // Callback when rejecting request

  const PatientCard({
    super.key,
    required this.patient,
    this.onTap,
    this.statusText,
    this.statusColor,
    this.isPending = false,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStatusColor =
        statusColor ?? (isPending ? Colors.orange : AppColors.primaryColor);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSmall),
      elevation: AppDimensions.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: AppDimensions.borderRadiusMedium,
        side: BorderSide(
          color: isPending
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.borderRadiusMedium,
        child: Padding(
          padding: AppDimensions.paddingAllSmall,
          child: Row(
            children: [
              // Patient Avatar
              InlineUserAvatar(
                userId: patient.uid,
                initialUrl: patient.avatarUrl,
                displayName: patient.name,
                radius: 24,
              ),
              const SizedBox(width: AppDimensions.spacingMedium),

              // Patient Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name, style: AppTextStyles.body1Bold),
                    const SizedBox(height: AppDimensions.spacingXSmall),
                    Text(
                      patient.email,
                      style: AppTextStyles.body2Secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (statusText != null) ...[
                      const SizedBox(height: AppDimensions.spacingXSmall),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: effectiveStatusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSmall),
                          Text(
                            statusText!,
                            style: AppTextStyles.caption.copyWith(
                              color: effectiveStatusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isPending) ...[
                TextButton(
                  onPressed: onAccept != null
                      ? () async {
                          await onAccept!();
                        }
                      : null,
                  child: Text(
                    'Đồng ý',
                    style: AppTextStyles.body2.copyWith(
                      color: onAccept != null ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onReject != null
                      ? () async {
                          await onReject!();
                        }
                      : null,
                  child: Text(
                    'Từ chối',
                    style: AppTextStyles.body2.copyWith(
                      color: onReject != null ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
              ],
              // Arrow icon
              const Icon(
                Icons.arrow_forward_ios,
                size: AppDimensions.iconSmall,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
