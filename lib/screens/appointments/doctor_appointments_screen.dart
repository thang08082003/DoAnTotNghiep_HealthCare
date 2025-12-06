import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/appointment_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/appointments/appointment_viewmodel.dart';
import '../../providers/user_provider.dart';
import 'appointment_detail_screen.dart';

/// Màn hình quản lý appointments cho bác sĩ
class DoctorAppointmentsScreen extends ConsumerStatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  ConsumerState<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState
    extends ConsumerState<DoctorAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      doctorAppointmentsViewModelProvider(currentUser.uid),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý lịch khám'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Chờ duyệt'),
            Tab(text: 'Đã xác nhận'),
            Tab(text: 'Hoàn thành'),
            Tab(text: 'Yêu cầu theo dõi'),
          ],
        ),
      ),
      body: appointmentsAsync.when(
        data: (appointments) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingList(appointments),
              _buildConfirmedList(appointments),
              _buildCompletedList(appointments),
              _buildFollowUpRequestsList(appointments),
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
    final pending =
        appointments
            .where((apt) => apt.status == AppointmentStatus.pending)
            .toList()
          ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));

    if (pending.isEmpty) {
      return const _EmptyState(
        icon: Icons.inbox,
        message: 'Không có lịch khám chờ duyệt',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) => _AppointmentCard(
        appointment: pending[index],
        showConfirmRejectActions: true,
      ),
    );
  }

  Widget _buildConfirmedList(List<Appointment> appointments) {
    final confirmed =
        appointments
            .where((apt) => apt.status == AppointmentStatus.confirmed)
            .toList()
          ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));

    if (confirmed.isEmpty) {
      return const _EmptyState(
        icon: Icons.check_circle_outline,
        message: 'Không có lịch khám đã xác nhận',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: confirmed.length,
      itemBuilder: (context, index) => _AppointmentCard(
        appointment: confirmed[index],
        showCompleteAction: true,
      ),
    );
  }

  Widget _buildCompletedList(List<Appointment> appointments) {
    final completed =
        appointments
            .where((apt) => apt.status == AppointmentStatus.completed)
            .toList()
          ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    if (completed.isEmpty) {
      return const _EmptyState(
        icon: Icons.done_all,
        message: 'Chưa có lịch khám hoàn thành',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completed.length,
      itemBuilder: (context, index) =>
          _AppointmentCard(appointment: completed[index]),
    );
  }

  Widget _buildFollowUpRequestsList(List<Appointment> appointments) {
    final followUpRequests =
        appointments
            .where(
              (apt) =>
                  apt.status == AppointmentStatus.completed &&
                  apt.followUpRequested &&
                  !apt.followUpAccepted,
            )
            .toList()
          ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    if (followUpRequests.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_add_disabled,
        message: 'Không có yêu cầu theo dõi mới',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: followUpRequests.length,
      itemBuilder: (context, index) => _AppointmentCard(
        appointment: followUpRequests[index],
        showAcceptFollowUpAction: true,
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  final Appointment appointment;
  final bool showConfirmRejectActions;
  final bool showCompleteAction;
  final bool showAcceptFollowUpAction;

  const _AppointmentCard({
    required this.appointment,
    this.showConfirmRejectActions = false,
    this.showCompleteAction = false,
    this.showAcceptFollowUpAction = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AppointmentDetailScreen(appointment: appointment),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getStatusIcon(), color: _getStatusColor(), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      DateFormat(
                        'EEEE, dd/MM/yyyy',
                      ).format(appointment.appointmentDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor()),
                    ),
                    child: Text(
                      appointment.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('HH:mm').format(appointment.appointmentDate),
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                appointment.reason,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (showConfirmRejectActions ||
                  showCompleteAction ||
                  showAcceptFollowUpAction) ...[
                const Divider(height: 24),
                _buildActions(context, ref),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    if (showConfirmRejectActions) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _handleReject(context, ref),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Từ chối'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _handleConfirm(context, ref),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Xác nhận'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (showCompleteAction) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _handleComplete(context, ref),
          icon: const Icon(Icons.done, size: 16),
          label: const Text('Hoàn thành'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (showAcceptFollowUpAction) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _handleAcceptFollowUp(context, ref),
          icon: const Icon(Icons.person_add, size: 16),
          label: const Text('Chấp nhận theo dõi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _handleConfirm(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final viewModel = ref.read(
        doctorAppointmentsViewModelProvider(currentUser.uid).notifier,
      );
      await viewModel.confirmAppointment(appointment.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận lịch khám'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Từ chối lịch khám'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Lý do từ chối',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Từ chối'),
            ),
          ],
        );
      },
    );

    if (reason == null || !context.mounted) return;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final viewModel = ref.read(
        doctorAppointmentsViewModelProvider(currentUser.uid).notifier,
      );
      await viewModel.rejectAppointment(appointment.id, reason: reason);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối lịch khám'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleComplete(BuildContext context, WidgetRef ref) async {
    final notes = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Hoàn thành khám'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Ghi chú của bác sĩ (tùy chọn)',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Hoàn thành'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final viewModel = ref.read(
        doctorAppointmentsViewModelProvider(currentUser.uid).notifier,
      );
      await viewModel.completeAppointment(
        appointment.id,
        doctorNotes: notes?.trim().isNotEmpty == true ? notes : null,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hoàn thành khám'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleAcceptFollowUp(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final viewModel = ref.read(
        doctorAppointmentsViewModelProvider(currentUser.uid).notifier,
      );
      await viewModel.acceptFollowUp(appointment.id);
      // Force refresh to immediately move item out of "Yêu cầu theo dõi"
      ref.invalidate(doctorAppointmentsViewModelProvider(currentUser.uid));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chấp nhận theo dõi bệnh nhân'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
          Icon(icon, size: 80, color: Colors.grey[400]),
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
