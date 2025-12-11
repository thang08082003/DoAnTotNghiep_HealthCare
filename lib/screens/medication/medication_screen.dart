import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/medication_model.dart';
import '../../data/services/medication_service.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/medication/medication_viewmodel.dart';
import '../../components/medication/medication_card.dart';
import '../../components/medication/medication_details_dialog.dart';

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
                  return MedicationCard(
                    medication: medication,
                    onTap: () => _showMedicationDetails(context, medication),
                    onDelete: () async {
                      await viewModel.deleteMedication(medication.id);
                    },
                    showReminders: true,
                    enableDismiss: true,
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
      builder: (context) => MedicationDetailsDialog(medication: medication),
    );
  }

  void _showAddMedicationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AddMedicationDialog(),
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
