import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/care_plan/action_menu_bottom_sheet.dart';
import '../../components/care_plan/create_goal_with_dates_bottom_sheet.dart';
import '../../components/care_plan/create_task_bottom_sheet.dart';
import '../../components/care_plan/goal_header_widget.dart';
import '../../components/care_plan/task_list_widget.dart';
import '../../data/models/care_plan_model.dart';
import '../../providers/user_provider.dart';

/// Goal Checklist Screen - View layer (MVVM)
/// Hiển thị danh sách tasks của một mục tiêu
/// Logic được xử lý bởi ViewModel, UI chỉ hiển thị và gọi actions
class GoalChecklistScreen extends ConsumerWidget {
  final HealthGoal goal;

  const GoalChecklistScreen({super.key, required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết mục tiêu'), centerTitle: true),
      body: Column(
        children: [
          // Goal Header - Component tách biệt
          GoalHeaderWidget(goal: goal),

          // Tasks List
          Expanded(child: TaskListWidget(goal: goal)),
        ],
      ),
      floatingActionButton: userAsync.when(
        data: (user) => user != null
            ? FloatingActionButton.extended(
                onPressed: () => showActionMenuBottomSheet(
                  context: context,
                  onCreateGoal: () => showCreateGoalWithDatesBottomSheet(
                    context: context,
                    userId: user.uid,
                  ),
                  onCreateTask: () => showCreateTaskBottomSheet(
                    context: context,
                    userId: user.uid,
                    preSelectedGoal: goal,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Tạo mới'),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}
