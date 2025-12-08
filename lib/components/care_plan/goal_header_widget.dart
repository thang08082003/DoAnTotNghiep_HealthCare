import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/care_plan_model.dart';
import '../../data/resources/gene/app_colors.dart';

/// Widget hiển thị header thông tin mục tiêu
class GoalHeaderWidget extends StatelessWidget {
  final HealthGoal goal;

  const GoalHeaderWidget({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (goal.description != null) ...[
            const SizedBox(height: 8),
            Text(
              goal.description!,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (goal.targetDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  'Mục tiêu: ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
