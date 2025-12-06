import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/appointment_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/appointments/appointment_viewmodel.dart';
import '../../providers/user_provider.dart';
import 'appointment_detail_screen.dart';
import 'package:intl/intl.dart';

/// Màn hình danh sách appointments cho bệnh nhân
class PatientAppointmentsScreen extends ConsumerStatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  ConsumerState<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState
    extends ConsumerState<PatientAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final appointmentsAsync = ref.watch(
      patientAppointmentsViewModelProvider(currentUser.uid),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch khám của tôi'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Chờ xác nhận'),
            Tab(text: 'Sắp tới'),
            Tab(text: 'Lịch sử'),
          ],
        ),
      ),
      body: appointmentsAsync.when(
        data: (appointments) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingList(appointments),
              _buildUpcomingList(appointments),
              _buildHistoryList(appointments),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Lỗi: ${error.toString()}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingList(List<Appointment> appointments) {
    final pending = appointments
        .where((apt) => apt.status == AppointmentStatus.pending)
        .toList();

    if (pending.isEmpty) {
      return const _EmptyState(
        icon: Icons.schedule,
        message: 'Không có lịch hẹn chờ xác nhận',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        return _AppointmentCard(
          appointment: pending[index],
          onTap: () => _navigateToDetail(pending[index]),
          onCancel: () => _handleCancel(pending[index]),
        );
      },
    );
  }

  Widget _buildUpcomingList(List<Appointment> appointments) {
    final now = DateTime.now();
    final upcoming = appointments
        .where(
          (apt) =>
              apt.status == AppointmentStatus.confirmed &&
              apt.appointmentDate.isAfter(now),
        )
        .toList();

    if (upcoming.isEmpty) {
      return const _EmptyState(
        icon: Icons.event_available,
        message: 'Không có lịch khám sắp tới',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcoming.length,
      itemBuilder: (context, index) {
        return _AppointmentCard(
          appointment: upcoming[index],
          onTap: () => _navigateToDetail(upcoming[index]),
          onCancel: () => _handleCancel(upcoming[index]),
        );
      },
    );
  }

  Widget _buildHistoryList(List<Appointment> appointments) {
    final now = DateTime.now();
    final history = appointments
        .where(
          (apt) =>
              apt.status == AppointmentStatus.completed ||
              apt.status == AppointmentStatus.cancelled ||
              apt.status == AppointmentStatus.rejected ||
              (apt.appointmentDate.isBefore(now) &&
                  apt.status != AppointmentStatus.pending),
        )
        .toList();

    if (history.isEmpty) {
      return const _EmptyState(
        icon: Icons.history,
        message: 'Chưa có lịch sử khám',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        return _AppointmentCard(
          appointment: history[index],
          onTap: () => _navigateToDetail(history[index]),
        );
      },
    );
  }

  void _navigateToDetail(Appointment appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(appointment: appointment),
      ),
    );
  }

  Future<void> _handleCancel(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lịch khám'),
        content: const Text('Bạn có chắc chắn muốn hủy lịch khám này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      try {
        final viewModel = ref.read(
          patientAppointmentsViewModelProvider(currentUser.uid).notifier,
        );
        await viewModel.cancelAppointment(appointment.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy lịch khám'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  const _AppointmentCard({
    required this.appointment,
    required this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
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
                      color: _getStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(),
                      color: _getStatusColor(),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'dd/MM/yyyy - HH:mm',
                          ).format(appointment.appointmentDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appointment.status.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onCancel != null &&
                      appointment.status == AppointmentStatus.pending)
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.error),
                      onPressed: onCancel,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.medical_services,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.reason,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (appointment.notes != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.note,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment.notes!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.confirmed:
        return Colors.blue;
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return Icons.schedule;
      case AppointmentStatus.confirmed:
        return Icons.check_circle;
      case AppointmentStatus.completed:
        return Icons.done_all;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.rejected:
        return Icons.cancel;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
