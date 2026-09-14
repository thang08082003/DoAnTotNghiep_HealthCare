import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';

/// A reusable tile widget for displaying resource information.
///
/// Features:
/// - Icon with circular background
/// - Title and subtitle text
/// - Chevron indicator for navigation
/// - Tap gesture handling
/// - Card-style shadow elevation
///
/// Usage:
/// ```dart
/// ResourceTile(
///   icon: Icons.menu_book,
///   title: 'Clinical Guidelines',
///   subtitle: 'Updated guidelines by specialty',
///   onTap: () => openUrl('https://...'),
/// )
/// ```
class ResourceTile extends StatelessWidget {
  /// Icon to display in the circular avatar
  final IconData icon;

  /// Primary title text
  final String title;

  /// Secondary subtitle text
  final String subtitle;

  /// Callback when tile is tapped
  final VoidCallback? onTap;

  /// Background color for the icon
  final Color? iconBackgroundColor;

  /// Color for the icon
  final Color? iconColor;

  const ResourceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconBackgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: iconBackgroundColor ?? const Color(0xFFE8F0FE),
              child: Icon(icon, color: iconColor ?? AppColors.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
