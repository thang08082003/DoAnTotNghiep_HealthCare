import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/care_plan_model.dart';
import '../../viewmodels/care_plan/care_plan_viewmodel.dart';
import 'health_goal_item_widget.dart';

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
            return HealthGoalItemWidget(
              goal: goal,
              onToggle: () => _handleToggleGoal(ref, userId, goal),
              onDelete: () =>
                  _showDeleteConfirmation(context, ref, userId, goal.id),
            );
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
          const SizedBox(height: 4),
          Text(
            'Tạo mục tiêu đầu tiên của bạn',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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

  Future<void> _handleToggleGoal(
    WidgetRef ref,
    String userId,
    HealthGoal goal,
  ) async {
    try {
      await ref
          .read(carePlanViewModelProvider(userId).notifier)
          .toggleGoalCompletion(goal.id, goal.isCompleted);
    } catch (e) {
      // Error handling được xử lý trong ViewModel
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String goalId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa mục tiêu này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(carePlanViewModelProvider(userId).notifier)
                    .deleteHealthGoal(goalId);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa mục tiêu')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
