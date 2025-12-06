import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/appointment_model.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/appointments/appointment_viewmodel.dart';
import '../../providers/user_provider.dart';
import '../../data/services/user_service.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final Appointment appointment;

  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  UserModel? _otherUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final userService = UserService();
      final userId = currentUser.isPatient
          ? widget.appointment.doctorId
          : widget.appointment.patientId;

      final user = await userService.getUserById(userId);
      if (mounted) {
        setState(() {
          _otherUser = user;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isPatient = currentUser.isPatient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết lịch khám'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBadge(),
            const SizedBox(height: 24),
            _buildInfoCard(
              icon: Icons.calendar_today,
              title: 'Ngày & Giờ khám',
              content: DateFormat(
                'EEEE, dd/MM/yyyy - HH:mm',
              ).format(widget.appointment.appointmentDate),
            ),
            const SizedBox(height: 16),
            if (_isLoadingUser)
              const Center(child: CircularProgressIndicator())
            else if (_otherUser != null)
              _buildUserInfoCard(isPatient),
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.medical_services,
              title: 'Lý do khám',
              content: widget.appointment.reason,
            ),
            const SizedBox(height: 16),
            if (widget.appointment.notes != null)
              _buildInfoCard(
                icon: Icons.note,
                title: 'Ghi chú',
                content: widget.appointment.notes!,
              ),
            const SizedBox(height: 16),
            if (widget.appointment.doctorNotes != null)
              _buildInfoCard(
                icon: Icons.description,
                title: 'Ghi chú của bác sĩ',
                content: widget.appointment.doctorNotes!,
                highlighted: true,
              ),
            const SizedBox(height: 16),
            if (widget.appointment.cancelReason != null)
              _buildInfoCard(
                icon: Icons.info_outline,
                title: 'Lý do hủy',
                content: widget.appointment.cancelReason!,
                color: AppColors.error,
              ),
            const SizedBox(height: 24),
            if (isPatient) _buildPatientActions(),
            if (!isPatient) _buildDoctorActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(), width: 2),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(), color: _getStatusColor(), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appointment.status.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusDescription(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    bool highlighted = false,
    Color? color,
  }) {
    return Card(
      elevation: highlighted ? 3 : 1,
      color: highlighted
          ? AppColors.primaryColor.withOpacity(0.05)
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color ?? AppColors.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(bool isPatient) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primaryColor.withOpacity(0.1),
              child: Text(
                _otherUser!.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPatient ? 'Bác sĩ' : 'Bệnh nhân',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _otherUser!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_otherUser!.phone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _otherUser!.phone!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientActions() {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return const SizedBox.shrink();

    if (widget.appointment.status == AppointmentStatus.completed &&
        !widget.appointment.followUpRequested) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleRequestFollowUp,
          icon: const Icon(Icons.follow_the_signs),
          label: const Text('Yêu cầu theo dõi từ bác sĩ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    if (widget.appointment.followUpRequested &&
        !widget.appointment.followUpAccepted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: const Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đã gửi yêu cầu theo dõi. Chờ bác sĩ chấp nhận.',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.appointment.followUpAccepted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bác sĩ đã chấp nhận theo dõi sức khỏe của bạn.',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDoctorActions() {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return const SizedBox.shrink();

    if (widget.appointment.status == AppointmentStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleReject,
              icon: const Icon(Icons.close),
              label: const Text('Từ chối'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _handleConfirm,
              icon: const Icon(Icons.check),
              label: const Text('Xác nhận'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.appointment.status == AppointmentStatus.confirmed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleComplete,
          icon: const Icon(Icons.done),
          label: const Text('Hoàn thành khám'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    if (widget.appointment.followUpRequested &&
        !widget.appointment.followUpAccepted) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleAcceptFollowUp,
          icon: const Icon(Icons.person_add),
          label: const Text('Chấp nhận theo dõi bệnh nhân'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _handleRequestFollowUp() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final viewModel = ref.read(
        patientAppointmentsViewModelProvider(currentUser.uid).notifier,
      );
      await viewModel.requestFollowUp(widget.appointment.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi yêu cầu theo dõi đến bác sĩ'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
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

  Future<void> _handleConfirm() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final viewModel = ref.read(
        doctorAppointmentsViewModelProvider(currentUser.uid).notifier,
      );
      await viewModel.confirmAppointment(widget.appointment.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận lịch khám'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
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

  Future<void> _handleReject() async {
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

    if (reason == null || !mounted) return;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final viewModel = ref.read(
        doctorAppointmentsViewModelProvider(currentUser.uid).notifier,
      );
      await viewModel.rejectAppointment(widget.appointment.id, reason: reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối lịch khám'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
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

  Future<void> _handleComplete() async {
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

    if (!mounted) return;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final viewModel = ref.read(
        doctorAppointmentsViewModelProvider(currentUser.uid).notifier,
      );
      await viewModel.completeAppointment(
        widget.appointment.id,
        doctorNotes: notes?.trim().isNotEmpty == true ? notes : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hoàn thành khám'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
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

  Future<void> _handleAcceptFollowUp() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    try {
      final viewModel = ref.read(
        doctorAppointmentsViewModelProvider(currentUser.uid).notifier,
      );
      await viewModel.acceptFollowUp(widget.appointment.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chấp nhận theo dõi bệnh nhân'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
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

  Color _getStatusColor() {
    switch (widget.appointment.status) {
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
    switch (widget.appointment.status) {
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

  String _getStatusDescription() {
    switch (widget.appointment.status) {
      case AppointmentStatus.pending:
        return 'Chờ bác sĩ xác nhận';
      case AppointmentStatus.confirmed:
        return 'Lịch khám đã được xác nhận';
      case AppointmentStatus.completed:
        return 'Đã hoàn thành khám';
      case AppointmentStatus.cancelled:
        return 'Lịch khám đã bị hủy';
      case AppointmentStatus.rejected:
        return 'Bác sĩ đã từ chối';
    }
  }
}
