import 'package:flutter/material.dart';
import '../../data/models/care_plan_model.dart';
import '../../data/resources/gene/app_colors.dart';

/// Widget hiển thị một checklist item
class ChecklistItemWidget extends StatelessWidget {
  final GoalChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const ChecklistItemWidget({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: item.isCompleted
                  ? AppColors.primaryColor
                  : Colors.transparent,
              border: Border.all(color: AppColors.primaryColor, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: item.isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            decoration: item.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: Colors.red.shade400,
            size: 20,
          ),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
