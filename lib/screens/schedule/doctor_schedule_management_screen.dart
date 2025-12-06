import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../data/models/doctor_schedule_model.dart';
import '../../data/services/doctor_schedule_service.dart';
import '../../providers/user_provider.dart';
import '../../data/resources/gene/app_colors.dart';
// import removed: bulk creation dialog is not used for doctor role
import 'time_slot_detail_screen.dart';

class DoctorScheduleManagementScreen extends ConsumerStatefulWidget {
  const DoctorScheduleManagementScreen({super.key});

  @override
  ConsumerState<DoctorScheduleManagementScreen> createState() =>
      _DoctorScheduleManagementScreenState();
}

class _DoctorScheduleManagementScreenState
    extends ConsumerState<DoctorScheduleManagementScreen> {
  final DoctorScheduleService _scheduleService = DoctorScheduleService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<DoctorSchedule> _schedules = [];
  DoctorSchedule? _selectedDaySchedule;
  bool _isLoading = false;
  Stream<List<DoctorSchedule>>? _scheduleStream;
  StreamSubscription<List<DoctorSchedule>>? _scheduleSub;

  @override
  void initState() {
    super.initState();
    _subscribeSchedules();
  }

  @override
  void dispose() {
    _scheduleSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Load schedules for current month
      final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      final schedules = await _scheduleService
          .getDoctorSchedulesByDateRange(user.uid, firstDay, lastDay)
          .first;

      setState(() {
        _schedules = schedules;
        _updateSelectedDaySchedule();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải lịch: $e')));
      }
    }
  }

  void _subscribeSchedules() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // Define current month range
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    // Cancel previous subscription
    _scheduleSub?.cancel();

    // Create new stream and subscribe
    _scheduleStream = _scheduleService.getDoctorSchedulesByDateRange(
      user.uid,
      firstDay,
      lastDay,
    );

    setState(() => _isLoading = true);

    _scheduleSub = _scheduleStream!.listen(
      (schedules) {
        if (!mounted) return;
        setState(() {
          _schedules = schedules;
          _updateSelectedDaySchedule();
          _isLoading = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải lịch: $e')));
      },
    );
  }

  void _updateSelectedDaySchedule() {
    _selectedDaySchedule = _schedules.firstWhere(
      (schedule) => isSameDay(schedule.date, _selectedDay),
      orElse: () => DoctorSchedule(
        id: '',
        doctorId: '',
        date: _selectedDay,
        timeSlots: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  bool _hasScheduleOnDay(DateTime day) {
    return _schedules.any((schedule) => isSameDay(schedule.date, day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý lịch làm việc'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showGuideDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar
          Card(
            margin: const EdgeInsets.all(12),
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              eventLoader: (day) {
                return _hasScheduleOnDay(day) ? ['schedule'] : [];
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _updateSelectedDaySchedule();
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _subscribeSchedules();
              },
            ),
          ),

          // Selected day info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(_selectedDay),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Time slots list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTimeSlotsList(),
          ),
        ],
      ),
      // Doctor role: creation actions removed (admin will manage schedules)
      floatingActionButton: null,
    );
  }

  Widget _buildTimeSlotsList() {
    if (_selectedDaySchedule?.timeSlots.isEmpty ?? true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch làm việc trong ngày này',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            // Creation action removed for doctor role
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _selectedDaySchedule!.timeSlots.length,
      itemBuilder: (context, index) {
        final slot = _selectedDaySchedule!.timeSlots[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: slot.isBooked
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              child: Icon(
                slot.isBooked ? Icons.event_busy : Icons.event_available,
                color: slot.isBooked ? Colors.red : Colors.green,
              ),
            ),
            title: Text(
              slot.displayTime,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              slot.isBooked ? 'Đã có lịch hẹn' : 'Còn trống',
              style: TextStyle(
                color: slot.isBooked ? Colors.red : Colors.green,
              ),
            ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  final schedule = _selectedDaySchedule;
                  if (schedule == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TimeSlotDetailScreen(
                        schedule: schedule,
                        slot: slot,
                      ),
                    ),
                  );
                },
          ),
        );
      },
    );
  }

  // Creation dialog removed for doctor role

  // Removed header edit action per UI request; keep slot-level edit/delete

  // Per-slot edit/delete dialogs removed in favor of dedicated detail screen

  // Helpers
  TimeOfDay? _parseTime(String hhmm) {
    try {
      final parts = hhmm.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(TimeOfDay? t) {
    if (t == null) return '--:--';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatHHmm(TimeOfDay t) => _formatTimeOfDay(t);

  // Removed header delete action per UI request; keep slot-level delete

  // Removed full-day delete handler per UI request

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hướng dẫn sử dụng'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📅 Chọn ngày trên lịch để xem/quản lý'),
              SizedBox(height: 8),
              Text('➕ Nhấn nút "Tạo lịch" để thêm lịch làm việc mới'),
              SizedBox(height: 8),
              Text('✏️ Nhấn biểu tượng sửa để chỉnh sửa lịch'),
              SizedBox(height: 8),
              Text(
                '🗑️ Nhấn biểu tượng xóa để xóa lịch (chỉ khi chưa có lịch hẹn)',
              ),
              SizedBox(height: 8),
              Text('🟢 Chấm xanh: Ngày có lịch làm việc'),
              SizedBox(height: 8),
              Text('🔒 Khung giờ đã khóa: Đã có bệnh nhân đặt lịch'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }
}

// Dialog tạo lịch đã loại bỏ khỏi màn hình của bác sĩ

// Dialog sửa lịch
class _EditScheduleDialog extends ConsumerStatefulWidget {
  final DoctorSchedule schedule;
  final VoidCallback onScheduleUpdated;

  const _EditScheduleDialog({
    required this.schedule,
    required this.onScheduleUpdated,
  });

  @override
  ConsumerState<_EditScheduleDialog> createState() =>
      _EditScheduleDialogState();
}

class _EditScheduleDialogState extends ConsumerState<_EditScheduleDialog> {
  final DoctorScheduleService _scheduleService = DoctorScheduleService();

  late bool _isAvailable;
  late String _note;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _isAvailable = widget.schedule.isAvailable;
    _note = widget.schedule.note ?? '';
  }

  Future<void> _updateSchedule() async {
    setState(() => _isUpdating = true);

    try {
      final updated = widget.schedule.copyWith(
        isAvailable: _isAvailable,
        note: _note.isEmpty ? null : _note,
        updatedAt: DateTime.now(),
      );

      await _scheduleService.updateSchedule(widget.schedule.id, updated);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật lịch thành công')),
        );
        widget.onScheduleUpdated();
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa lịch làm việc'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Trạng thái làm việc'),
            subtitle: Text(
              _isAvailable ? 'Đang nhận lịch' : 'Tạm ngưng nhận lịch',
            ),
            value: _isAvailable,
            onChanged: (val) => setState(() => _isAvailable = val),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'VD: Nghỉ, Hội nghị...',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (val) => _note = val,
            controller: TextEditingController(text: _note),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isUpdating ? null : _updateSchedule,
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
