import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/care_plan_model.dart';
import '../../providers/user_provider.dart';
import 'health_goal_card_with_actions.dart';

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
    final currentUser = ref.watch(currentUserProvider).value;
    final isPatientView =
        currentUser?.uid == userId; // Viewing own goals as patient

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

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: goals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 0),
          itemBuilder: (context, index) {
            return HealthGoalCardWithActions(
              goal: goals[index],
              isPatientView: isPatientView,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có mục tiêu nào',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
