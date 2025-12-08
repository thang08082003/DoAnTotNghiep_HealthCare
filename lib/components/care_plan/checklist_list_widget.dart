import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/care_plan_model.dart';
import '../../viewmodels/care_plan/goal_checklist_viewmodel.dart';
import 'checklist_empty_state_widget.dart';
import 'checklist_item_widget.dart';

/// Widget hiển thị danh sách checklist items
class ChecklistListWidget extends ConsumerWidget {
  final HealthGoal goal;

  const ChecklistListWidget({super.key, required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModelNotifier = ref.read(
      goalChecklistViewModelProvider(goal).notifier,
    );

    return StreamBuilder<List<GoalChecklistItem>>(
      stream: viewModelNotifier.getChecklistItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Lỗi: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const ChecklistEmptyStateWidget();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length + 1, // +1 for bottom spacing
          itemBuilder: (context, index) {
            if (index == items.length) {
              return const SizedBox(height: 80); // Space for FAB
            }

            final item = items[index];
            return ChecklistItemWidget(
              item: item,
              onToggle: () =>
                  _handleToggleItem(context, ref, viewModelNotifier, item),
              onDelete: () => _showDeleteConfirmation(
                context,
                ref,
                viewModelNotifier,
                item.id,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleToggleItem(
    BuildContext context,
    WidgetRef ref,
    GoalChecklistViewModel viewModelNotifier,
    GoalChecklistItem item,
  ) async {
    try {
      await viewModelNotifier.toggleItemCompletion(item.id, item.isCompleted);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    GoalChecklistViewModel viewModelNotifier,
    String itemId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa mục này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await viewModelNotifier.deleteChecklistItem(itemId);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Đã xóa mục')));
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
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
