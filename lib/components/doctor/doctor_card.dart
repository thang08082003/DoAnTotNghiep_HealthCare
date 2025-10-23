import 'package:flutter/material.dart';
import '../buttons/primary_button.dart';
import '../../data/models/doctor_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../reviews/reviews_summary.dart';
import '../../viewmodels/reviews/doctor_reviews_view_model.dart';

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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Doctor Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: doctor.hasAvatar
                        ? NetworkImage(doctor.avatarUrl!)
                        : null,
                    backgroundColor: AppColors.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: !doctor.hasAvatar
                        ? Icon(
                            Icons.person,
                            size: 30,
                            color: AppColors.primaryColor,
                          )
                        : null,
                  ),
                  SizedBox(width: 16),

                  // Doctor Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          doctor.specialty.vietnameseName,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        SizedBox(height: 2),
                        Text(
                          'Kinh nghiệm: ${doctor.yearsExperience != null ? '${doctor.yearsExperience} năm' : 'Chưa cập nhật'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Role indicator
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Bác sĩ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Specialization info
              Row(
                children: [
                  Icon(
                    Icons.medical_services,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Chuyên khoa: ${doctor.specialty.vietnameseName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // Rating row (avg), optional
              if (showRating) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ReviewsSummary(
                        doctorId: doctor.uid,
                        reviewsVm: DoctorReviewsViewModel(),
                        compact: true,
                      ),
                    ),
                    if (onRate != null)
                      TextButton.icon(
                        onPressed: onRate,
                        icon: const Icon(Icons.rate_review, size: 16),
                        label: const Text('Đánh giá'),
                      ),
                  ],
                ),
              ],

              if (primaryActionText != null) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  text: primaryActionText!,
                  onPressed: primaryActionDisabled ? null : onPrimaryAction,
                  height: 40,
                  fontSize: 14,
                ),
              ] else if (showBookButton) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  text: 'Đặt lịch khám',
                  onPressed: onBookAppointment,
                  height: 40,
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundImage: doctor.hasAvatar
              ? NetworkImage(doctor.avatarUrl!)
              : null,
          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
          child: !doctor.hasAvatar
              ? Icon(Icons.person, size: 20, color: AppColors.primaryColor)
              : null,
        ),
        title: Text(
          doctor.name,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doctor.specialty.vietnameseName,
              style: TextStyle(color: AppColors.primaryColor, fontSize: 13),
            ),
            Text(
              doctor.email,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
