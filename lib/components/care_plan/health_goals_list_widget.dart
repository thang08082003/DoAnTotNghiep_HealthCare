import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/care_plan_model.dart';
import 'health_goal_item_widget.dart' hide Text;

// Widget hiển thị danh sách mục tiêu
class HealthGoalsListWidget extends ConsumerWidget {
  final String userId;
  final Stream<List<HealthGoal>> goalsStream;

  const HealthGoalsListWidget({
    super.key,
    required this.userId,
    required this.goalsStream,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<HealthGoal>>(
      stream: goalsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState('Lỗi: ${snapshot.error}');
        }

        final goals = snapshot.data ?? [];

        if (goals.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: goals.map((goal) {
            return HealthGoalItemWidget(goal: goal);
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.flag_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Chưa có mục tiêu',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}
