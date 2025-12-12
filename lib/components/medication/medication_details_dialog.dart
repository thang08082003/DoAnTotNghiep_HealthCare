import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/medication_model.dart';
import '../../data/services/medication_reminder_service.dart';
import '../../viewmodels/medication/medication_viewmodel.dart';
import '../../screens/medication/medication_reminder_dialog.dart';

/// A dialog that displays detailed information about a medication.
///
/// Features:
/// - Medication details display (dosage, frequency, dates, etc.)
/// - Reminder information with active count badge
/// - Actions: Add/Edit reminders, Activate/Deactivate medication
/// - Integration with MedicationViewModel and MedicationReminderService
///
/// Usage:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => MedicationDetailsDialog(
///     medication: medication,
///   ),
/// );
/// ```
class MedicationDetailsDialog extends ConsumerWidget {
  /// The medication to display details for
  final Medication medication;

  const MedicationDetailsDialog({super.key, required this.medication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(medicationViewModelProvider.notifier);
    final reminderService = ref.watch(medicationReminderServiceProvider);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(medication.name)),
          // Reminder icon with count badge
          StreamBuilder(
            stream: reminderService.getRemindersByMedication(medication.id),
            builder: (context, snapshot) {
              final reminders = snapshot.data ?? [];
              final activeReminders = reminders
                  .where((r) => r.isActive)
                  .toList();
              if (activeReminders.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alarm, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${activeReminders.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (medication.dosage != null)
              _DetailRow(
                icon: Icons.medication,
                label: 'Liều lượng',
                value: medication.dosage!,
              ),
            if (medication.frequency != null) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.schedule,
                label: 'Tần suất',
                value: medication.frequency!,
              ),
            ],
            if (medication.instructions != null) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.info,
                label: 'Hướng dẫn',
                value: medication.instructions!,
                maxLines: 3,
              ),
            ],
            if (medication.startDate != null) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.calendar_today,
                label: 'Ngày bắt đầu',
                value: DateFormat('dd/MM/yyyy').format(medication.startDate!),
              ),
            ],
            if (medication.endDate != null) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.event,
                label: 'Ngày kết thúc',
                value: DateFormat('dd/MM/yyyy').format(medication.endDate!),
              ),
            ],
            if (medication.notes != null) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.note,
                label: 'Ghi chú',
                value: medication.notes!,
                maxLines: 5,
              ),
            ],
            // Reminder times section
            StreamBuilder(
              stream: reminderService.getRemindersByMedication(medication.id),
              builder: (context, snapshot) {
                final reminders = snapshot.data ?? [];
                final activeReminders = reminders
                    .where((r) => r.isActive)
                    .toList();
                if (activeReminders.isEmpty) return const SizedBox.shrink();

                final reminder = activeReminders.first;
                final times = reminder.reminderTimes
                    .map((t) => t.toString())
                    .join(', ');

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.alarm,
                      label: 'Lịch nhắc',
                      value: times,
                      valueColor: Colors.blue,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: medication.isActive ? Icons.check_circle : Icons.cancel,
              label: 'Trạng thái',
              value: medication.isActive ? 'Đang sử dụng' : 'Đã ngưng',
            ),
          ],
        ),
      ),
      actions: [
        // Reminder button
        StreamBuilder(
          stream: reminderService.getRemindersByMedication(medication.id),
          builder: (context, snapshot) {
            final reminders = snapshot.data ?? [];
            final existingReminder = reminders.isEmpty ? null : reminders.first;

            return TextButton.icon(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => MedicationReminderDialog(
                    medication: medication,
                    existingReminder: existingReminder,
                  ),
                );
              },
              icon: Icon(
                existingReminder != null && existingReminder.isActive
                    ? Icons.alarm_on
                    : Icons.alarm_add,
              ),
              label: Text(
                existingReminder != null ? 'Sửa lịch nhắc' : 'Thêm lịch nhắc',
              ),
            );
          },
        ),
        if (medication.isActive)
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.deactivateMedication(medication.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            icon: const Icon(Icons.pause_circle_outline, size: 20),
            label: const Text('Ngưng sử dụng'),
          )
        else
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.activateMedication(medication.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            icon: const Icon(Icons.play_circle_outline, size: 20),
            label: const Text('Sử dụng lại'),
          ),
      ],
    );
  }
}

/// Internal widget for displaying a detail row with icon, label, and value
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 14, color: valueColor),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
