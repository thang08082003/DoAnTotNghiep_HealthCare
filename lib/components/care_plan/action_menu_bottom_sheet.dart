import 'package:flutter/material.dart';

/// Bottom sheet hiển thị menu các hành động
/// - Tạo mục tiêu tổng
/// - Tạo việc cần làm
class ActionMenuBottomSheet extends StatelessWidget {
  final VoidCallback onCreateGoal;
  final VoidCallback onCreateTask;

  const ActionMenuBottomSheet({
    super.key,
    required this.onCreateGoal,
    required this.onCreateTask,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            const Text(
              'Chọn hành động',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Create Goal option
            _ActionMenuItem(
              icon: Icons.flag,
              iconColor: Colors.blue,
              title: 'Tạo mục tiêu tổng',
              subtitle: 'Tạo mục tiêu mới với ngày hoặc khoảng thời gian',
              onTap: () {
                Navigator.pop(context);
                onCreateGoal();
              },
            ),

            const Divider(height: 24),

            // Create Task option
            _ActionMenuItem(
              icon: Icons.task_alt,
              iconColor: Colors.green,
              title: 'Tạo việc cần làm',
              subtitle: 'Uống thuốc, đo huyết áp, tập thể dục...',
              onTap: () {
                Navigator.pop(context);
                onCreateTask();
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Widget cho từng item trong menu
class _ActionMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Arrow icon
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

/// Function để hiển thị action menu bottom sheet
void showActionMenuBottomSheet({
  required BuildContext context,
  required VoidCallback onCreateGoal,
  required VoidCallback onCreateTask,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ActionMenuBottomSheet(
      onCreateGoal: onCreateGoal,
      onCreateTask: onCreateTask,
    ),
  );
}
