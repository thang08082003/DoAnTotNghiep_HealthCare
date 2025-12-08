import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/medication_model.dart';
import '../../data/models/medication_reminder_model.dart';
import '../../data/services/medication_reminder_service.dart';
import '../../providers/user_provider.dart';

/// Dialog thiết lập lịch nhắc thuốc
class MedicationReminderDialog extends ConsumerStatefulWidget {
  final Medication medication;
  final MedicationReminder? existingReminder; // null nếu tạo mới

  const MedicationReminderDialog({
    super.key,
    required this.medication,
    this.existingReminder,
  });

  @override
  ConsumerState<MedicationReminderDialog> createState() =>
      _MedicationReminderDialogState();
}

class _MedicationReminderDialogState
    extends ConsumerState<MedicationReminderDialog> {
  final List<ReminderTime> _selectedTimes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingReminder != null) {
      _selectedTimes.addAll(widget.existingReminder!.reminderTimes);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (time != null) {
      // Convert to ReminderTime
      final reminderTime = MedicationReminder.fromTimeOfDay(time);

      // Check if time already exists
      final alreadyExists = _selectedTimes.any(
        (t) => t.hour == reminderTime.hour && t.minute == reminderTime.minute,
      );

      if (alreadyExists) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Giờ này đã được thêm')));
        }
        return;
      }

      setState(() {
        _selectedTimes.add(reminderTime);
        _selectedTimes.sort((a, b) {
          if (a.hour != b.hour) return a.hour.compareTo(b.hour);
          return a.minute.compareTo(b.minute);
        });
      });
    }
  }

  void _removeTime(ReminderTime time) {
    setState(() {
      _selectedTimes.removeWhere(
        (t) => t.hour == time.hour && t.minute == time.minute,
      );
    });
  }

  Future<void> _saveReminder() async {
    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một giờ nhắc')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) throw Exception('User not found');

      final service = ref.read(medicationReminderServiceProvider);

      if (widget.existingReminder != null) {
        // Update existing
        final updated = widget.existingReminder!.copyWith(
          reminderTimes: _selectedTimes,
        );
        await service.updateReminder(updated);
      } else {
        // Create new
        final reminder = MedicationReminder(
          id: '', // Will be set by Firestore
          medicationId: widget.medication.id,
          userId: user.uid,
          medicationName: widget.medication.name,
          reminderTimes: _selectedTimes,
          isActive: true,
          createdAt: DateTime.now(),
        );
        await service.addReminder(reminder);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingReminder != null
                  ? 'Đã cập nhật lịch nhắc'
                  : 'Đã thêm lịch nhắc',
            ),
          ),
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingReminder != null
            ? 'Chỉnh sửa lịch nhắc'
            : 'Thiết lập lịch nhắc',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medication info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.medication.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (widget.medication.dosage != null)
                          Text(
                            widget.medication.dosage!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Times list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Giờ nhắc',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : _pickTime,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm giờ'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_selectedTimes.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Chưa có giờ nhắc nào',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedTimes.map((time) {
                  return Chip(
                    avatar: const Icon(Icons.alarm, size: 18),
                    label: Text(
                      time.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: _isLoading ? null : () => _removeTime(time),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // Helper text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn sẽ nhận thông báo nhắc uống thuốc vào các giờ đã chọn mỗi ngày',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveReminder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(widget.existingReminder != null ? 'Cập nhật' : 'Lưu'),
        ),
      ],
    );
  }
}
