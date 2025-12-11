import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/care_plan_model.dart';
import '../../data/resources/gene/app_colors.dart';

/// A reusable card widget for displaying health goal information.
///
/// Features:
/// - Completion status indicator (check/circle icon)
/// - Strike-through text for completed goals
/// - Optional description display
/// - Target date display with calendar icon
/// - Responsive card layout
///
/// Usage:
/// ```dart
/// GoalCard(
///   goal: HealthGoal(
///     id: 'goal1',
///     title: 'Exercise 30 minutes daily',
///     description: 'Cardio or strength training',
///     targetDate: DateTime(2025, 12, 31),
///     isCompleted: false,
///   ),
/// )
/// ```
class GoalCard extends StatelessWidget {
  /// The health goal to display
  final HealthGoal goal;

  /// Optional callback when card is tapped
  final VoidCallback? onTap;

  /// Whether to show elevation shadow
  final bool showElevation;

  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.showElevation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: showElevation ? null : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    goal.isCompleted
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: goal.isCompleted
                        ? Colors.green
                        : AppColors.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: goal.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (goal.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  goal.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    decoration: goal.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ],
              if (goal.targetDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Mục tiêu: ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
