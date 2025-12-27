import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/care_plan_model.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../data/services/care_plan_service.dart';
import '../../../providers/user_provider.dart';

/// Bottom sheet cho bác sĩ chỉnh sửa health goal
class EditHealthGoalBottomSheet extends ConsumerStatefulWidget {
  final HealthGoal existingGoal;

  const EditHealthGoalBottomSheet({super.key, required this.existingGoal});

  @override
  ConsumerState<EditHealthGoalBottomSheet> createState() =>
      _EditHealthGoalBottomSheetState();
}

class _EditHealthGoalBottomSheetState
    extends ConsumerState<EditHealthGoalBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetValueController;
  late final TextEditingController _frequencyController;

  late HealthGoalType _selectedType;
  DateTime? _targetDate;
  List<TimeOfDay> _reminderTimes = [];

  // For measurement type
  String? _measurementType;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeFromExisting();
  }

  void _initializeFromExisting() {
    final goal = widget.existingGoal;

    _titleController = TextEditingController(text: goal.title);
    _descriptionController = TextEditingController(
      text: goal.description ?? '',
    );
    _targetValueController = TextEditingController(
      text: goal.targetValue ?? '',
    );
    _frequencyController = TextEditingController(text: goal.frequency ?? '');

    _selectedType = goal.type;
    _targetDate = goal.targetDate;
    _measurementType = goal.measurementType;

    // Parse reminder times
    if (goal.reminderTimes != null) {
      _reminderTimes = goal.reminderTimes!.map((timeStr) {
        final parts = timeStr.split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('Không tìm thấy thông tin bác sĩ');
      }

      final carePlanService = ref.read(carePlanServiceProvider);

      // Convert TimeOfDay list to HH:mm string format
      final reminderTimesStr = _reminderTimes.map((time) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }).toList();

      final updates = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'targetDate': _targetDate,
        'reminderTimes': reminderTimesStr.isNotEmpty ? reminderTimesStr : null,
        'updatedAt': DateTime.now(),
        'status': HealthGoalStatus
            .pendingPatientReview
            .value, // Reset to pending after edit
        'patientResponse': null, // Clear previous response
        'isFinalEdit': false, // Reset final edit flag when doctor edits
        'requiresVideoCall':
            false, // Reset video call requirement after doctor edits
        // Keep modificationRequestCount - don't reset (để track lịch sử)
      };

      // Add type-specific fields
      if (_selectedType == HealthGoalType.measurement) {
        updates['measurementType'] = _measurementType;
        updates['targetValue'] = _targetValueController.text.trim();
        updates['frequency'] = _frequencyController.text.trim().isEmpty
            ? null
            : _frequencyController.text.trim();
      }

      await carePlanService.updateHealthGoal(widget.existingGoal.id, updates);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật mục tiêu thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      const Text(
                        'Chỉnh sửa mục tiêu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Patient feedback (if any)
                  if (widget.existingGoal.patientResponse != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.feedback,
                                color: Colors.orange.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Phản hồi từ bệnh nhân:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.existingGoal.patientResponse!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Type badge (read-only, cannot change type)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedType.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedType.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_selectedType.icon, color: _selectedType.color),
                        const SizedBox(width: 8),
                        Text(
                          'Loại: ${_selectedType.displayName}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _selectedType.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tiêu đề';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Measurement-specific fields
                  if (_selectedType == HealthGoalType.measurement) ...[
                    _buildMeasurementFields(),
                    const SizedBox(height: 16),
                  ],

                  // Target date
                  _buildTargetDateField(),
                  const SizedBox(height: 16),

                  // Reminder
                  _buildReminderField(),
                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Cập nhật mục tiêu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _measurementType,
          decoration: const InputDecoration(
            labelText: 'Loại đo',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.speed),
          ),
          items: const [
            DropdownMenuItem(value: 'blood_pressure', child: Text('Huyết áp')),
            DropdownMenuItem(value: 'blood_sugar', child: Text('Đường huyết')),
            DropdownMenuItem(value: 'weight', child: Text('Cân nặng')),
            DropdownMenuItem(value: 'heart_rate', child: Text('Nhịp tim')),
            DropdownMenuItem(value: 'temperature', child: Text('Nhiệt độ')),
          ],
          onChanged: (value) => setState(() => _measurementType = value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _targetValueController,
          decoration: const InputDecoration(
            labelText: 'Giá trị mục tiêu',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.track_changes),
            hintText: 'VD: 120/80, <100mg/dL, 65kg',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _frequencyController,
          decoration: const InputDecoration(
            labelText: 'Tần suất',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.repeat),
            hintText: 'VD: Mỗi ngày, 2 lần/ngày, Mỗi tuần',
          ),
        ),
      ],
    );
  }

  Widget _buildTargetDateField() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _targetDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() => _targetDate = date);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Ngày mục tiêu',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(
          _targetDate != null
              ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
              : 'Chọn ngày',
          style: TextStyle(
            color: _targetDate != null ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Giờ nhắc nhở (tùy chọn)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Display selected reminder times
        if (_reminderTimes.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reminderTimes.map((time) {
              return Chip(
                label: Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                avatar: const Icon(Icons.access_time, size: 18),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _reminderTimes.remove(time);
                  });
                },
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                deleteIconColor: AppColors.primaryColor,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Add reminder time button
        OutlinedButton.icon(
          onPressed: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                );
              },
            );
            if (time != null) {
              setState(() {
                // Check if time already exists
                if (!_reminderTimes.any(
                  (t) => t.hour == time.hour && t.minute == time.minute,
                )) {
                  _reminderTimes.add(time);
                  // Sort times
                  _reminderTimes.sort((a, b) {
                    if (a.hour != b.hour) return a.hour.compareTo(b.hour);
                    return a.minute.compareTo(b.minute);
                  });
                }
              });
            }
          },
          icon: const Icon(Icons.add_alarm),
          label: Text(
            _reminderTimes.isEmpty ? 'Thêm giờ nhắc' : 'Thêm giờ nhắc khác',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryColor,
            side: const BorderSide(color: AppColors.primaryColor),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),

        if (_reminderTimes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bệnh nhân sẽ nhận ${_reminderTimes.length} thông báo mỗi ngày',
                    style: const TextStyle(color: Colors.blue, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
