import 'package:flutter/material.dart';
import '../buttons/primary_button.dart';
import '../../data/models/doctor_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/resources/gene/app_text_styles.dart';
import '../../data/resources/gene/app_dimensions.dart';
import '../reviews/inline_user_avatar.dart';

class DoctorCard extends StatelessWidget {
  final DoctorModel doctor;
  final VoidCallback? onTap;
  final bool showBookButton;
  final VoidCallback? onBookAppointment;
  final String? primaryActionText;
  final VoidCallback? onPrimaryAction;
  final bool primaryActionDisabled;
  final bool showRating; // show avg rating under card
  final VoidCallback? onRate; // optional quick action

  const DoctorCard({
    super.key,
    required this.doctor,
    this.onTap,
    this.showBookButton = true,
    this.onBookAppointment,
    this.primaryActionText,
    this.onPrimaryAction,
    this.primaryActionDisabled = false,
    this.showRating = true,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: AppDimensions.marginCard,
      elevation: AppDimensions.elevationMedium,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.borderRadiusSmall,
        child: Padding(
          padding: AppDimensions.paddingAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Doctor Avatar
                  InlineUserAvatar(
                    userId: doctor.uid,
                    initialUrl: doctor.avatarUrl,
                    displayName: doctor.name,
                    radius: 30,
                  ),
                  const SizedBox(width: AppDimensions.spacingMedium),

                  // Doctor Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctor.name, style: AppTextStyles.heading3),
                        const SizedBox(height: AppDimensions.spacingXSmall),
                        Text(
                          doctor.specialty.vietnameseName,
                          style: AppTextStyles.body2Bold.copyWith(
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingXSmall),
                        Text(
                          'Kinh nghiệm: ${doctor.yearsExperience != null ? '${doctor.yearsExperience} năm' : 'Chưa cập nhật'}',
                          style: AppTextStyles.labelSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (primaryActionText != null) ...[
                const SizedBox(height: AppDimensions.spacingMedium),
                PrimaryButton(
                  text: primaryActionText!,
                  onPressed: primaryActionDisabled ? null : onPrimaryAction,
                  height: AppDimensions.buttonHeightSmall,
                  fontSize: 14,
                ),
              ] else if (showBookButton) ...[
                const SizedBox(height: AppDimensions.spacingMedium),
                PrimaryButton(
                  text: 'Đặt lịch khám',
                  onPressed: onBookAppointment,
                  height: AppDimensions.buttonHeightSmall,
                  fontSize: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Compact version for lists
class DoctorCompactCard extends StatelessWidget {
  final DoctorModel doctor;
  final VoidCallback? onTap;

  const DoctorCompactCard({super.key, required this.doctor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingValue,
        vertical: AppDimensions.spacingXSmall,
      ),
      elevation: AppDimensions.elevationLow,
      child: ListTile(
        leading: InlineUserAvatar(
          userId: doctor.uid,
          initialUrl: doctor.avatarUrl,
          displayName: doctor.name,
          radius: 20,
        ),
        title: Text(doctor.name, style: AppTextStyles.body1Bold),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doctor.specialty.vietnameseName,
              style: AppTextStyles.labelSecondary.copyWith(
                color: AppColors.primaryColor,
              ),
            ),
            Text(doctor.email, style: AppTextStyles.caption),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: AppDimensions.iconSmall,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
