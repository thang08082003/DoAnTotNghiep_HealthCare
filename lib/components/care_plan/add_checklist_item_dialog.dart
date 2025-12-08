import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/care_plan_model.dart';
import '../../viewmodels/care_plan/goal_checklist_viewmodel.dart';

/// Dialog để thêm checklist item mới
class AddChecklistItemDialog extends ConsumerStatefulWidget {
  final HealthGoal goal;

  const AddChecklistItemDialog({super.key, required this.goal});

  @override
  ConsumerState<AddChecklistItemDialog> createState() =>
      _AddChecklistItemDialogState();
}

class _AddChecklistItemDialogState
    extends ConsumerState<AddChecklistItemDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(goalChecklistViewModelProvider(widget.goal));

    return AlertDialog(
      title: const Text('Thêm mục mới'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Ví dụ: Tập thể dục 30 phút',
          border: OutlineInputBorder(),
        ),
        maxLines: 2,
        enabled: !viewModel.isAddingItem,
      ),
      actions: [
        TextButton(
          onPressed: viewModel.isAddingItem
              ? null
              : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: viewModel.isAddingItem ? null : () => _handleAddItem(),
          child: viewModel.isAddingItem
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Thêm'),
        ),
      ],
    );
  }

  Future<void> _handleAddItem() async {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập nội dung')));
      return;
    }

    try {
      final viewModelNotifier = ref.read(
        goalChecklistViewModelProvider(widget.goal).notifier,
      );
      await viewModelNotifier.createChecklistItem(title);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm mục mới'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// Helper function để show dialog
void showAddChecklistItemDialog(BuildContext context, HealthGoal goal) {
  showDialog(
    context: context,
    builder: (context) => AddChecklistItemDialog(goal: goal),
  );
}
