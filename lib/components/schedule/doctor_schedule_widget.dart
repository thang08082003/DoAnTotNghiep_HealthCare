import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/doctor_schedule_model.dart';
import '../../data/services/doctor_schedule_service.dart';
import '../../providers/user_provider.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../screens/schedule/doctor_schedule_management_screen.dart';

class DoctorScheduleWidget extends ConsumerStatefulWidget {
  const DoctorScheduleWidget({super.key});

  @override
  ConsumerState<DoctorScheduleWidget> createState() =>
      _DoctorScheduleWidgetState();
}

class _DoctorScheduleWidgetState extends ConsumerState<DoctorScheduleWidget> {
  final DoctorScheduleService _scheduleService = DoctorScheduleService();
  DoctorSchedule? _todaySchedule;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodaySchedule();
  }

  Future<void> _loadTodaySchedule() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      final schedule = await _scheduleService.getDoctorScheduleByDate(
        user.uid,
        DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _todaySchedule = schedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorScheduleManagementScreen(),
            ),
          );
        },
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
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_month,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lịch làm việc hôm nay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.now()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_todaySchedule == null)
                _buildNoSchedule()
              else
                _buildScheduleInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSchedule() {
    return Column(
      children: [
        Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          'Chưa có lịch làm việc hôm nay',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DoctorScheduleManagementScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Tạo lịch'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleInfo() {
    final totalSlots = _todaySchedule!.timeSlots.length;
    final bookedSlots = _todaySchedule!.timeSlots
        .where((s) => s.isBooked)
        .length;
    final availableSlots = totalSlots - bookedSlots;

    return Column(
      children: [
        // Statistics
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Tổng số khung giờ',
                totalSlots.toString(),
                Icons.access_time,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Đã đặt',
                bookedSlots.toString(),
                Icons.event_busy,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Còn trống',
                availableSlots.toString(),
                Icons.event_available,
                Colors.green,
              ),
            ),
          ],
        ),

        // Status
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _todaySchedule!.isAvailable
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _todaySchedule!.isAvailable
                    ? Icons.check_circle
                    : Icons.pause_circle,
                color: _todaySchedule!.isAvailable
                    ? Colors.green
                    : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _todaySchedule!.isAvailable
                    ? 'Đang nhận lịch hẹn'
                    : 'Tạm ngưng nhận lịch',
                style: TextStyle(
                  color: _todaySchedule!.isAvailable
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Note
        if (_todaySchedule!.note != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Ghi chú: ${_todaySchedule!.note}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
