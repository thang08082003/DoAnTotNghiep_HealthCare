import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/care_plan_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/goal_reminder_service.dart';
import '../dialog/custom_dialog.dart';

// Widget hiển thị một mục tiêu
class HealthGoalItemWidget extends ConsumerWidget {
  final HealthGoal goal;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const HealthGoalItemWidget({
    super.key,
    required this.goal,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async {
        return await CustomDialog.showConfirmation(
          context: context,
          title: 'Xác nhận xóa',
          message: 'Bạn có chắc muốn xóa mục tiêu "${goal.title}"?',
          confirmText: 'Xóa',
          cancelText: 'Hủy',
        );
      },
      onDismissed: (direction) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: goal.isCompleted
                      ? AppColors.primaryColor
                      : Colors.transparent,
                  border: Border.all(color: AppColors.primaryColor, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: goal.isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      decoration: goal.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (goal.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      goal.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        decoration: goal.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
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
                  if (goal.hasReminder && goal.reminderTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          size: 14,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Nhắc lúc: ${DateFormat('HH:mm').format(goal.reminderTime!)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Reminder button
            IconButton(
              icon: Icon(
                goal.hasReminder
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: goal.hasReminder ? AppColors.primaryColor : Colors.grey,
                size: 20,
              ),
              onPressed: () => _showReminderDialog(context, ref),
              tooltip: goal.hasReminder ? 'Sửa nhắc nhở' : 'Thêm nhắc nhở',
            ),
          ],
        ),
      ),
    );
  }

  void _showReminderDialog(BuildContext context, WidgetRef ref) {
    final reminderService = ref.read(goalReminderServiceProvider);
    TimeOfDay? selectedTime = goal.reminderTime != null
        ? TimeOfDay.fromDateTime(goal.reminderTime!)
        : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(goal.hasReminder ? 'Sửa nhắc nhở' : 'Thêm nhắc nhở'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn thời gian nhắc nhở hàng ngày',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          timePickerTheme: TimePickerThemeData(
                            backgroundColor: Colors.white,
                            hourMinuteColor: AppColors.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            hourMinuteTextColor: AppColors.primaryColor,
                            dialHandColor: AppColors.primaryColor,
                            dialBackgroundColor: AppColors.primaryColor
                                .withValues(alpha: 0.1),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null) {
                    setState(() => selectedTime = time);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedTime != null
                            ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                            : 'Chọn giờ',
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedTime != null
                              ? AppColors.textPrimary
                              : Colors.grey.shade600,
                        ),
                      ),
                      Icon(Icons.access_time, color: AppColors.primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (goal.hasReminder)
              TextButton(
                onPressed: () async {
                  try {
                    await reminderService.removeGoalReminder(goal.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã xóa nhắc nhở')),
                      );
                    }
                  } catch (e) {
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: selectedTime == null
                  ? null
                  : () async {
                      try {
                        final now = DateTime.now();
                        final reminderTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          selectedTime!.hour,
                          selectedTime!.minute,
                        );

                        await reminderService.setGoalReminderTime(
                          goalId: goal.id,
                          reminderTime: reminderTime,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Đã đặt nhắc nhở thành công'),
                            ),
                          );
                        }
                      } catch (e) {
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
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
