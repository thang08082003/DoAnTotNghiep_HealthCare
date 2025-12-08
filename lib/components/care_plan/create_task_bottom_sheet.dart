import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/care_plan_model.dart';
import '../../data/services/care_plan_service.dart';

/// Bottom sheet để tạo task (việc cần làm) cho nhiều mục tiêu
class CreateTaskBottomSheet extends ConsumerStatefulWidget {
  final String userId;
  final HealthGoal? preSelectedGoal;

  const CreateTaskBottomSheet({
    super.key,
    required this.userId,
    this.preSelectedGoal,
  });

  @override
  ConsumerState<CreateTaskBottomSheet> createState() =>
      _CreateTaskBottomSheetState();
}

class _CreateTaskBottomSheetState extends ConsumerState<CreateTaskBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedGoalIds = {}; // Chọn nhiều mục tiêu
  TaskType _selectedType = TaskType.medication;
  TimeOfDay? _selectedTime;
  bool _notificationEnabled = true;
  bool _isLoading = false;
  late final Stream<List<HealthGoal>> _goalsStream;

  @override
  void initState() {
    super.initState();
    // Cache stream để tránh reload khi setState()
    _goalsStream = ref
        .read(carePlanServiceProvider)
        .getHealthGoals(widget.userId);
    if (widget.preSelectedGoal != null) {
      _selectedGoalIds.add(widget.preSelectedGoal!.id);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createTasks(List<HealthGoal> allGoals) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGoalIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một mục tiêu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final carePlanService = ref.read(carePlanServiceProvider);

      final scheduledTime = _selectedTime != null
          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
          : null;

      // Tạo task cho từng mục tiêu đã chọn
      int successCount = 0;
      for (final goalId in _selectedGoalIds) {
        final goal = allGoals.firstWhere((g) => g.id == goalId);

        if (goal.targetDate == null) {
          print('⚠️ Bỏ qua goal ${goal.title} vì không có targetDate');
          continue;
        }

        print('📝 Đang tạo task cho goal: ${goal.title} (${goal.id})');
        print('   - Title: ${_titleController.text.trim()}');
        print('   - Type: ${_selectedType.name}');
        print('   - Date: ${goal.targetDate}');
        print('   - Time: $scheduledTime');

        await carePlanService.createGoalTask(
          goalId: goal.id,
          userId: widget.userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          scheduledDates: [goal.targetDate!], // Dùng ngày của mục tiêu
          scheduledTime: scheduledTime,
          type: _selectedType,
          notificationEnabled: _notificationEnabled,
        );
        print('✅ Đã tạo task thành công cho goal ${goal.title}');
        successCount++;
      }

      print('🎉 Tổng số task đã tạo: $successCount');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo việc cần làm cho $successCount mục tiêu'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ LỖI khi tạo task: $e');
      print('Stack trace: $stackTrace');
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

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Widget _buildGoalSelector(List<HealthGoal> goals) {
    if (widget.preSelectedGoal != null && goals.length == 1) {
      final goal = goals.first;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.flag, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (goal.targetDate != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(goal.targetDate!),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Chọn mục tiêu:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (_selectedGoalIds.length == goals.length) {
                    _selectedGoalIds.clear();
                  } else {
                    _selectedGoalIds.addAll(goals.map((g) => g.id));
                  }
                });
              },
              icon: Icon(
                _selectedGoalIds.length == goals.length
                    ? Icons.deselect
                    : Icons.select_all,
                size: 18,
              ),
              label: Text(
                _selectedGoalIds.length == goals.length
                    ? 'Bỏ chọn tất cả'
                    : 'Chọn tất cả',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: goals.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final goal = goals[index];
              final isSelected = _selectedGoalIds.contains(goal.id);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedGoalIds.add(goal.id);
                    } else {
                      _selectedGoalIds.remove(goal.id);
                    }
                  });
                },
                title: Text(
                  goal.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: goal.targetDate != null
                    ? Text(
                        DateFormat(
                          'EEEE, dd/MM/yyyy',
                          'vi_VN',
                        ).format(goal.targetDate!),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      )
                    : const Text(
                        'Chưa có ngày',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                secondary: Icon(
                  Icons.flag,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: StreamBuilder<List<HealthGoal>>(
          stream: _goalsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có mục tiêu nào',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vui lòng tạo mục tiêu trước khi tạo việc cần làm',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ],
              );
            }

            final goals = snapshot.data!;

            return SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title
                    const Text(
                      'Tạo việc cần làm',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Goal selector with multi-select
                    _buildGoalSelector(goals),
                    const SizedBox(height: 16),

                    // Selected count
                    if (_selectedGoalIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Đã chọn ${_selectedGoalIds.length} mục tiêu',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Task type selector
                    DropdownButtonFormField<TaskType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Loại việc',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      isExpanded: true,
                      items: TaskType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(type.icon, size: 20),
                              const SizedBox(width: 8),
                              Text(type.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _selectedType = value);
                              }
                            },
                    ),
                    const SizedBox(height: 16),

                    // Task Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Tên việc cần làm',
                        hintText: 'Ví dụ: Uống thuốc aspirin 100mg',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(_selectedType.icon),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên việc cần làm';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (không bắt buộc)',
                        hintText: 'Liều lượng, lưu ý...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Time picker
                    InkWell(
                      onTap: _isLoading ? null : _selectTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Giờ thực hiện (không bắt buộc)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _selectedTime != null
                              ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                              : 'Chọn giờ',
                          style: TextStyle(
                            color: _selectedTime != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notification toggle
                    SwitchListTile(
                      title: const Text('Bật thông báo'),
                      subtitle: _selectedTime != null
                          ? Text(
                              'Nhắc nhở lúc ${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                            )
                          : const Text('Nhắc nhở khi đến giờ'),
                      value: _notificationEnabled,
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() => _notificationEnabled = value);
                            },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Create button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _createTasks(goals),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _selectedGoalIds.isEmpty
                                        ? 'Tạo việc'
                                        : 'Tạo cho ${_selectedGoalIds.length} mục tiêu',
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Function để hiển thị bottom sheet tạo task
void showCreateTaskBottomSheet({
  required BuildContext context,
  required String userId,
  HealthGoal? preSelectedGoal,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        CreateTaskBottomSheet(userId: userId, preSelectedGoal: preSelectedGoal),
  );
}
