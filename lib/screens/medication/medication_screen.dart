import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/medication_model.dart';
import '../../data/services/medication_service.dart';
import '../../data/services/medication_reminder_service.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/medication/medication_viewmodel.dart';
import '../../components/dialog/custom_dialog.dart';
import 'medication_reminder_dialog.dart';

/// Trang quản lý thuốc - View layer (MVVM)
class MedicationScreen extends ConsumerWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final viewModel = ref.watch(medicationViewModelProvider.notifier);
    final state = ref.watch(medicationViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thuốc của tôi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              state.showActiveOnly ? Icons.filter_list : Icons.filter_list_off,
            ),
            onPressed: () => viewModel.toggleShowActiveOnly(),
            tooltip: state.showActiveOnly ? 'Hiển thị tất cả' : 'Chỉ đang dùng',
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Vui lòng đăng nhập'));
          }

          final medicationService = ref.watch(medicationServiceProvider);
          final stream = state.showActiveOnly
              ? medicationService.getActiveMedications(user.uid)
              : medicationService.getMedications(user.uid);

          return StreamBuilder<List<Medication>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text('Lỗi: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final medications = snapshot.data ?? [];

              if (medications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.showActiveOnly
                            ? 'Chưa có thuốc nào đang sử dụng'
                            : 'Chưa có thuốc nào',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nhấn nút "Thêm" để thêm thuốc',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: medications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final medication = medications[index];
                  return _MedicationCard(
                    medication: medication,
                    onTap: () => _showMedicationDetails(context, medication),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMedicationDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thuốc'),
      ),
    );
  }

  void _showMedicationDetails(BuildContext context, Medication medication) {
    showDialog(
      context: context,
      builder: (context) => _MedicationDetailsDialog(medication: medication),
    );
  }

  void _showAddMedicationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AddMedicationDialog(),
    );
  }
}

class _MedicationCard extends ConsumerWidget {
  final Medication medication;
  final VoidCallback onTap;

  const _MedicationCard({required this.medication, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(medicationViewModelProvider.notifier);

    return Dismissible(
      key: Key(medication.id),
      direction: DismissDirection.endToStart,
      background: Container(
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
          message: 'Bạn có chắc muốn xóa thuốc "${medication.name}"?',
          confirmText: 'Xóa',
          cancelText: 'Hủy',
        );
      },
      onDismissed: (direction) async {
        try {
          await viewModel.deleteMedication(medication.id);
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
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: medication.isActive
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.medication,
                        color: medication.isActive
                            ? Colors.orange
                            : Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medication.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (medication.dosage != null)
                            Text(
                              medication.dosage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!medication.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Đã ngưng',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                  ],
                ),
                if (medication.frequency != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        medication.frequency!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
                if (medication.startDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Từ ${DateFormat('dd/MM/yyyy').format(medication.startDate!)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      if (medication.endDate != null)
                        Text(
                          ' đến ${DateFormat('dd/MM/yyyy').format(medication.endDate!)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ],
                // Reminder times display
                StreamBuilder(
                  stream: ref
                      .watch(medicationReminderServiceProvider)
                      .getRemindersByMedication(medication.id),
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

                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.alarm, size: 16, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Nhắc lúc: $times',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.orange,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicationDetailsDialog extends ConsumerWidget {
  final Medication medication;

  const _MedicationDetailsDialog({required this.medication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(medicationViewModelProvider.notifier);
    final reminderService = ref.watch(medicationReminderServiceProvider);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(medication.name)),
          // Reminder icon with count
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
                  color: Colors.orange,
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
                      valueColor: Colors.orange,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.pause_circle_outline, size: 20),
            label: const Text('Ngưng sử dụng'),
          )
        else
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.activateMedication(medication.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.play_circle_outline, size: 20),
            label: const Text('Sử dụng lại'),
          ),
      ],
    );
  }
}

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

class _AddMedicationDialog extends ConsumerStatefulWidget {
  const _AddMedicationDialog();

  @override
  ConsumerState<_AddMedicationDialog> createState() =>
      _AddMedicationDialogState();
}

class _AddMedicationDialogState extends ConsumerState<_AddMedicationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _instructionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addMedication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

      final service = ref.read(medicationServiceProvider);
      await service.addMedication(
        userId: user.uid,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim().isNotEmpty
            ? _dosageController.text.trim()
            : null,
        frequency: _frequencyController.text.trim().isNotEmpty
            ? _frequencyController.text.trim()
            : null,
        instructions: _instructionsController.text.trim().isNotEmpty
            ? _instructionsController.text.trim()
            : null,
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm thuốc'),
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm thuốc'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên thuốc *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên thuốc';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Liều lượng',
                  hintText: 'VD: 100mg, 2 viên',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _frequencyController,
                decoration: const InputDecoration(
                  labelText: 'Tần suất',
                  hintText: 'VD: 2 lần/ngày, sáng tối',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Hướng dẫn',
                  hintText: 'VD: Uống sau ăn',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
                maxLines: 2,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
                enabled: !_isLoading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addMedication,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Thêm'),
        ),
      ],
    );
  }
}
