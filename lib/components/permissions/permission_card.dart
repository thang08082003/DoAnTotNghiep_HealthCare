import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/resources/gene/app_colors.dart';

/// A model class representing a permission item with its metadata.
class PermissionItem {
  /// The permission type from permission_handler
  final Permission permission;

  /// Display title for the permission
  final String title;

  /// Description explaining why this permission is needed
  final String description;

  /// Icon representing the permission
  final IconData icon;

  /// Whether this permission is required for the app to function
  final bool isRequired;

  const PermissionItem({
    required this.permission,
    required this.title,
    required this.description,
    required this.icon,
    required this.isRequired,
  });
}

/// A reusable card widget for displaying permission information.
///
/// Features:
/// - Icon with colored background
/// - Permission title and description
/// - "Required" badge for mandatory permissions
/// - Consistent styling with app theme
///
/// Usage:
/// ```dart
/// PermissionCard(
///   item: PermissionItem(
///     permission: Permission.camera,
///     title: 'Camera',
///     description: 'Needed for video calls',
///     icon: Icons.videocam,
///     isRequired: true,
///   ),
/// )
/// ```
class PermissionCard extends StatelessWidget {
  /// The permission item containing all metadata
  final PermissionItem item;

  /// Optional callback when card is tapped
  final VoidCallback? onTap;

  const PermissionCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: AppColors.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.isRequired) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Bắt buộc',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
