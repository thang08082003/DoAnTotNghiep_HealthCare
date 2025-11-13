import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';

class PatientCard extends StatelessWidget {
  final UserModel patient;
  final VoidCallback? onTap;
  final String? statusText; // e.g., "Đang theo dõi", "Đang chờ xác nhận"
  final Color? statusColor; // Color for status indicator
  final bool isPending; // true for pending requests

  const PatientCard({
    super.key,
    required this.patient,
    this.onTap,
    this.statusText,
    this.statusColor,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStatusColor =
        statusColor ?? (isPending ? Colors.orange : AppColors.primaryColor);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPending
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Patient Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: effectiveStatusColor.withValues(alpha: 0.1),
                backgroundImage:
                    (patient.avatarUrl != null && patient.avatarUrl!.isNotEmpty)
                    ? NetworkImage(patient.avatarUrl!)
                    : null,
                child: (patient.avatarUrl == null || patient.avatarUrl!.isEmpty)
                    ? Icon(Icons.person, size: 28, color: effectiveStatusColor)
                    : null,
              ),
              const SizedBox(width: 12),

              // Patient Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patient.email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (statusText != null) ...[
                      const SizedBox(height: 4),
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
                          const SizedBox(width: 6),
                          Text(
                            statusText!,
                            style: TextStyle(
                              fontSize: 12,
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

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
