import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/medication_model.dart';
import '../../data/resources/gene/app_dimensions.dart';
import '../../data/resources/gene/app_text_styles.dart';
import '../../data/services/medication_reminder_service.dart';

/// Reusable Medication Card Component
///
/// Supports two modes:
/// 1. Display mode (default) - Read-only card for viewing medication info
/// 2. Interactive mode - With tap, delete, and reminder display
class MedicationCard extends ConsumerWidget {
  final Medication medication;

  /// Callback when card is tapped (null for display-only mode)
  final VoidCallback? onTap;

  /// Callback when delete is confirmed (null for display-only mode)
  final Future<void> Function()? onDelete;

  /// Whether to show medication reminders (default: false)
  final bool showReminders;

  /// Whether the card is dismissible for deletion (default: false)
  final bool enableDismiss;

  const MedicationCard({
    super.key,
    required this.medication,
    this.onTap,
    this.onDelete,
    this.showReminders = false,
    this.enableDismiss = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardWidget = _buildCard(context, ref);

    // Wrap with Dismissible if delete is enabled
    if (enableDismiss && onDelete != null) {
      return Dismissible(
        key: Key(medication.id),
        direction: DismissDirection.endToStart,
        background: _buildDismissBackground(),
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmation(context);
        },
        onDismissed: (direction) async {
          try {
            await onDelete!();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa thuốc'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
        child: cardWidget,
      );
    }

    return cardWidget;
  }

  Widget _buildCard(BuildContext context, WidgetRef ref) {
    final card = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppDimensions.borderRadiusLarge,
      ),
      child: Padding(
        padding: AppDimensions.paddingAllMedium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (medication.frequency != null) ...[
              SizedBox(height: AppDimensions.spacingSmall),
              _buildFrequency(),
            ],
            if (medication.instructions != null) ...[
              SizedBox(height: AppDimensions.spacingSmall),
              _buildInstructions(),
            ],
            if (medication.startDate != null) ...[
              SizedBox(height: AppDimensions.spacingSmall),
              _buildDateRange(),
            ],
            if (showReminders) ...[_buildReminderDisplay(ref)],
          ],
        ),
      ),
    );

    // Wrap with InkWell if tappable
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.borderRadiusLarge,
        child: card,
      );
    }

    return card;
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: medication.isActive
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: AppDimensions.borderRadiusMedium,
          ),
          child: Icon(
            Icons.medication,
            color: medication.isActive ? Colors.blue : Colors.grey,
            size: 24,
          ),
        ),
        SizedBox(width: AppDimensions.spacingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(medication.name, style: AppTextStyles.body1Bold),
              if (medication.dosage != null)
                Text(medication.dosage!, style: AppTextStyles.body2Secondary),
            ],
          ),
        ),
        if (!medication.isActive) _buildInactiveChip(),
      ],
    );
  }

  Widget _buildInactiveChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Đã ngưng',
        style: TextStyle(fontSize: 11, color: Colors.black54),
      ),
    );
  }

  Widget _buildFrequency() {
    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(medication.frequency!, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildInstructions() {
    return Text(medication.instructions!, style: AppTextStyles.caption);
  }

  Widget _buildDateRange() {
    return Row(
      children: [
        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          'Từ ${DateFormat('dd/MM/yyyy').format(medication.startDate!)}',
          style: AppTextStyles.caption,
        ),
        if (medication.endDate != null)
          Text(
            ' đến ${DateFormat('dd/MM/yyyy').format(medication.endDate!)}',
            style: AppTextStyles.caption,
          ),
      ],
    );
  }

  Widget _buildReminderDisplay(WidgetRef ref) {
    return StreamBuilder(
      stream: ref
          .watch(medicationReminderServiceProvider)
          .getRemindersByMedication(medication.id),
      builder: (context, snapshot) {
        final reminders = snapshot.data ?? [];
        final activeReminders = reminders.where((r) => r.isActive).toList();
        if (activeReminders.isEmpty) return const SizedBox.shrink();

        final reminder = activeReminders.first;
        final times = reminder.reminderTimes
            .map((t) => t.toString())
            .join(', ');

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const Icon(Icons.alarm, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Nhắc lúc: $times',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: AppDimensions.borderRadiusLarge,
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white, size: 32),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa thuốc "${medication.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
