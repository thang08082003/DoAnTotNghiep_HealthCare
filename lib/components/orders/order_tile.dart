import 'package:flutter/material.dart';
import '../../data/models/doctor_order.dart';
import '../../data/resources/gene/app_colors.dart';

/// A reusable tile widget for displaying doctor orders
///
/// Features:
/// - Check icon indicator (teal color)
/// - Order title (bold)
/// - Optional notes section
/// - Creation date with formatted display
/// - Card-style container with border
///
/// Usage:
/// ```dart
/// OrderTile(
///   order: DoctorOrder(
///     title: 'Complete blood count test',
///     notes: 'Fasting required',
///     createdAt: DateTime.now(),
///   ),
/// )
/// ```
class OrderTile extends StatelessWidget {
  /// The doctor order to display
  final DoctorOrder order;

  const OrderTile({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final created = order.createdAt != null
        ? '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year}'
        : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((order.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.notes!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                if (created.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    created,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
