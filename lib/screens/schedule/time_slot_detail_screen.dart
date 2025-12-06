import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_schedule_model.dart';
import '../../data/models/appointment_model.dart';
import '../../data/services/appointment_service.dart';
import '../../providers/user_provider.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/appointments/appointment_viewmodel.dart';

class TimeSlotDetailScreen extends ConsumerStatefulWidget {
  final DoctorSchedule schedule;
  final TimeSlot slot;

  const TimeSlotDetailScreen({
    super.key,
    required this.schedule,
    required this.slot,
  });

  @override
  ConsumerState<TimeSlotDetailScreen> createState() => _TimeSlotDetailScreenState();
}

class _TimeSlotDetailScreenState extends ConsumerState<TimeSlotDetailScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  Appointment? _appointment;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppointment();
  }

  Future<void> _loadAppointment() async {
    if (!widget.slot.isBooked || widget.slot.appointmentId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final appt = await _appointmentService.getAppointmentById(widget.slot.appointmentId!);
      setState(() { _appointment = appt; _loading = false; });
    } catch (e) {
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final isDoctor = user?.isDoctor ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết khung giờ'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Khung giờ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('${widget.slot.displayTime} · ${_dateStr(widget.schedule.date)}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        widget.slot.isBooked ? Icons.event_busy : Icons.event_available,
                        color: widget.slot.isBooked ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(widget.slot.isBooked ? 'Đã có lịch hẹn' : 'Còn trống'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) Text('Lỗi: $_error', style: const TextStyle(color: Colors.red)),

            if (_appointment != null) _buildAppointmentSection(isDoctor),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentSection(bool isDoctor) {
    final appt = _appointment!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thông tin lịch hẹn', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Bệnh nhân: ${appt.patientId}'),
          Text('Trạng thái: ${appt.status.name}'),
          if (appt.followUpRequested == true)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildFollowUpActions(appt, isDoctor),
            ),
        ],
      ),
    );
  }

  Widget _buildFollowUpActions(Appointment appt, bool isDoctor) {
    // Cho phép bác sĩ chấp nhận/từ chối yêu cầu theo dõi liên quan tới cuộc hẹn này
    if (!isDoctor) return const SizedBox.shrink();
    return Row(
      children: [
        FilledButton(
          onPressed: () async {
            final doctorId = ref.read(currentUserProvider).value?.uid ?? '';
            if (doctorId.isEmpty) return;
            await ref
                .read(doctorAppointmentsViewModelProvider(doctorId).notifier)
                .acceptFollowUp(appt.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã chấp nhận yêu cầu theo dõi')),
              );
            }
          },
          child: const Text('Chấp nhận theo dõi'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () async {
            final doctorId = ref.read(currentUserProvider).value?.uid ?? '';
            if (doctorId.isEmpty) return;
            await ref
                .read(doctorAppointmentsViewModelProvider(doctorId).notifier)
                .declineFollowUp(appt.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã từ chối yêu cầu theo dõi')),
              );
            }
          },
          child: const Text('Từ chối'),
        ),
      ],
    );
  }

  String _dateStr(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }
}