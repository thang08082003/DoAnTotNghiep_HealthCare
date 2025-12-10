import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/care_plan/care_plan_calendar_widget.dart';
import '../../components/care_plan/create_goal_with_dates_bottom_sheet.dart';
import '../../components/care_plan/health_goals_list_widget.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/care_plan/care_plan_viewmodel.dart';

/// Main Care Plan Screen - View layer (MVVM)
/// Chỉ hiển thị UI, logic được xử lý bởi ViewModel
class CarePlanScreen extends ConsumerWidget {
  const CarePlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kế hoạch chăm sóc'), centerTitle: true),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Lỗi: $error')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Vui lòng đăng nhập'));
          }

          // Watch state from ViewModel
          final viewModel = ref.watch(carePlanViewModelProvider(user.uid));
          final viewModelNotifier = ref.read(
            carePlanViewModelProvider(user.uid).notifier,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calendar widget - Component tách biệt
                CarePlanCalendarWidget(
                  selectedDate: viewModel.selectedDate,
                  onDaySelected: (selectedDay, focusedDay) {
                    viewModelNotifier.selectDate(selectedDay);
                  },
                ),
                const SizedBox(height: 24),

                // Health Goals Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mục tiêu tổng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Health Goals List - Component tách biệt
                // Key giúp widget rebuild khi selectedDate thay đổi
                HealthGoalsListWidget(
                  key: ValueKey(viewModel.selectedDate),
                  userId: user.uid,
                  goalsStream: viewModelNotifier.getHealthGoalsStream(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
      floatingActionButton: userAsync.when(
        data: (user) => user != null
            ? FloatingActionButton.extended(
                onPressed: () => showCreateGoalWithDatesBottomSheet(
                  context: context,
                  userId: user.uid,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Tạo mục tiêu'),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}
