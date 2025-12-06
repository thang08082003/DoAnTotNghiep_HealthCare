import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_schedule_model.dart';
import '../../data/services/doctor_schedule_service.dart';
import '../../providers/user_provider.dart';
import '../../data/resources/gene/app_colors.dart';

/// Dialog để tạo lịch làm việc hàng loạt (theo tuần hoặc tháng)
class BulkScheduleCreationDialog extends ConsumerStatefulWidget {
  const BulkScheduleCreationDialog({super.key});

  @override
  ConsumerState<BulkScheduleCreationDialog> createState() =>
      _BulkScheduleCreationDialogState();
}

class _BulkScheduleCreationDialogState
    extends ConsumerState<BulkScheduleCreationDialog> {
  final DoctorScheduleService _scheduleService = DoctorScheduleService();

  // Chọn kiểu tạo: tuần hoặc tháng
  String _creationType = 'week'; // 'week' or 'month'

  // Chọn ngày bắt đầu
  DateTime _startDate = DateTime.now();

  // Chọn các ngày trong tuần
  final Map<int, bool> _selectedWeekdays = {
    1: true, // Monday
    2: true, // Tuesday
    3: true, // Wednesday
    4: true, // Thursday
    5: true, // Friday
    6: false, // Saturday
    7: false, // Sunday
  };

  // Chọn buổi làm việc
  bool _morning = true;
  bool _afternoon = true;

  bool _isCreating = false;

  List<DateTime> _generateDates() {
    final dates = <DateTime>[];
    
    if (_creationType == 'week') {
      // Tạo lịch cho 1 tuần (7 ngày)
      for (int i = 0; i < 7; i++) {
        final date = _startDate.add(Duration(days: i));
        final weekday = date.weekday;
        
        if (_selectedWeekdays[weekday] ?? false) {
          dates.add(date);
        }
      }
    } else {
      // Tạo lịch cho 1 tháng
      final daysInMonth = DateTime(_startDate.year, _startDate.month + 1, 0).day;
      
      for (int i = 0; i < daysInMonth; i++) {
        final date = DateTime(_startDate.year, _startDate.month, i + 1);
        final weekday = date.weekday;
        
        // Chỉ tạo cho các ngày được chọn
        if (_selectedWeekdays[weekday] ?? false) {
          dates.add(date);
        }
      }
    }
    
    return dates;
  }

  List<TimeSlot> _getSelectedTimeSlots() {
    final slots = <TimeSlot>[];
    if (_morning) slots.addAll(DefaultTimeSlots.morningSlots);
    if (_afternoon) slots.addAll(DefaultTimeSlots.afternoonSlots);
    return slots;
  }

  Future<void> _createBulkSchedules() async {
    // Validate
    if (!_selectedWeekdays.values.any((selected) => selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một ngày trong tuần')),
      );
      return;
    }

    if (!_morning && !_afternoon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một buổi làm việc')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('Không tìm thấy thông tin người dùng');

      final dates = _generateDates();
      final timeSlots = _getSelectedTimeSlots();

      // Upsert từng ngày để tránh trùng lịch
      for (final date in dates) {
        await _scheduleService.upsertScheduleForDate(
          doctorId: user.uid,
          date: date,
          timeSlots: timeSlots
              .map((slot) => TimeSlot(
                    startTime: slot.startTime,
                    endTime: slot.endTime,
                  ))
              .toList(),
          isAvailable: true,
          mergeSlots: true,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo lịch cho ${dates.length} ngày'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final generatedDates = _generateDates();

    return AlertDialog(
      title: const Text('Tạo lịch hàng loạt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chọn kiểu tạo
            const Text(
              'Loại lịch:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Tuần này'),
                    value: 'week',
                    groupValue: _creationType,
                    onChanged: (val) {
                      setState(() => _creationType = val!);
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Tháng này'),
                    value: 'month',
                    groupValue: _creationType,
                    onChanged: (val) {
                      setState(() => _creationType = val!);
                    },
                  ),
                ),
              ],
            ),

            const Divider(),

            // Chọn ngày bắt đầu
            const Text(
              'Ngày bắt đầu:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                '${_startDate.day}/${_startDate.month}/${_startDate.year}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
            ),

            const Divider(),

            // Chọn các ngày trong tuần
            const Text(
              'Ngày làm việc trong tuần:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildWeekdayChip('T2', 1),
                _buildWeekdayChip('T3', 2),
                _buildWeekdayChip('T4', 3),
                _buildWeekdayChip('T5', 4),
                _buildWeekdayChip('T6', 5),
                _buildWeekdayChip('T7', 6),
                _buildWeekdayChip('CN', 7),
              ],
            ),

            const Divider(),

            // Chọn buổi làm việc
            const Text(
              'Buổi làm việc:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              title: const Text('Sáng (8:00-12:00)'),
              dense: true,
              value: _morning,
              onChanged: (val) => setState(() => _morning = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Chiều (13:00-17:00)'),
              dense: true,
              value: _afternoon,
              onChanged: (val) => setState(() => _afternoon = val ?? false),
            ),
            // Removed evening session per new business rule

            const Divider(),

            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tóm tắt:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('• Số ngày: ${generatedDates.length}'),
                  Text(
                      '• Số khung giờ/ngày: ${_getSelectedTimeSlots().length}'),
                  Text(
                      '• Tổng khung giờ: ${generatedDates.length * _getSelectedTimeSlots().length}'),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createBulkSchedules,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Tạo lịch'),
        ),
      ],
    );
  }

  Widget _buildWeekdayChip(String label, int weekday) {
    final isSelected = _selectedWeekdays[weekday] ?? false;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedWeekdays[weekday] = selected;
        });
      },
      selectedColor: AppColors.primaryColor.withOpacity(0.3),
    );
  }
}
