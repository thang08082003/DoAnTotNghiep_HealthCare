import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/care_plan_model.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../data/services/care_plan_service.dart';

class PatientCarePlanTab extends ConsumerWidget {
  final String patientId;
  final bool isPending;

  const PatientCarePlanTab({
    super.key,
    required this.patientId,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isPending) {
      return _buildPendingMessage();
    }

    final carePlanService = ref.watch(carePlanServiceProvider);

    return StreamBuilder<List<HealthGoal>>(
      stream: carePlanService.getHealthGoals(patientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final goals = snapshot.data ?? [];
        if (goals.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Bệnh nhân chưa có mục tiêu nào'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: goals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final goal = goals[index];
            return _GoalCard(goal: goal);
          },
        );
      },
    );
  }

  Widget _buildPendingMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.orange.shade300),
            const SizedBox(height: 16),
            const Text(
              'Thông tin này sẽ hiển thị sau khi bạn chấp nhận yêu cầu theo dõi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final HealthGoal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  goal.isCompleted ? Icons.check_circle : Icons.circle_outlined,
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
