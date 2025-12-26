import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/medication_prescription_model.dart';
import '../../../data/services/prescription_service.dart';
import '../../../data/resources/gene/app_dimensions.dart';
import '../../../data/resources/gene/app_text_styles.dart';
import '../../../screens/patients/widgets/create_prescription_bottom_sheet.dart';
import '../../../screens/call/prescription_call_wrapper.dart';
import '../../../providers/user_provider.dart';
import '../../../viewmodels/call/call_view_model.dart';
import '../../../viewmodels/chat/chat_thread_view_model.dart';

class PrescriptionCard extends ConsumerStatefulWidget {
  final MedicationPrescription prescription;
  final bool isPatientView; // true nếu bệnh nhân xem, false nếu bác sĩ xem

  const PrescriptionCard({
    super.key,
    required this.prescription,
    this.isPatientView = true,
  });

  @override
  ConsumerState<PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends ConsumerState<PrescriptionCard> {
  bool _isExpanded = false;

  Color _getStatusColor() {
    switch (widget.prescription.status) {
      case PrescriptionStatus.pendingPatientReview:
        return Colors.orange;
      case PrescriptionStatus.approvedByPatient:
      case PrescriptionStatus.active:
        return Colors.green;
      case PrescriptionStatus.rejected:
        return Colors.red;
      case PrescriptionStatus.modificationRequested:
        return Colors.blue;
      case PrescriptionStatus.expired:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.prescription.status) {
      case PrescriptionStatus.pendingPatientReview:
        return Icons.pending_outlined;
      case PrescriptionStatus.approvedByPatient:
      case PrescriptionStatus.active:
        return Icons.check_circle_outline;
      case PrescriptionStatus.rejected:
        return Icons.cancel_outlined;
      case PrescriptionStatus.modificationRequested:
        return Icons.edit_outlined;
      case PrescriptionStatus.expired:
        return Icons.timer_off_outlined;
    }
  }

  Future<void> _handleAccept() async {
    try {
      final service = ref.read(prescriptionServiceProvider);
      await service.updatePrescriptionStatus(
        prescriptionId: widget.prescription.id,
        status: PrescriptionStatus.approvedByPatient,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã chấp nhận đơn thuốc. Hệ thống đang tạo nhắc nhở...',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject() async {
    final reason = await _showReasonDialog(
      title: 'Lý do từ chối',
      hint: 'Vui lòng cho biết lý do từ chối đơn thuốc này',
    );
    if (reason == null || reason.trim().isEmpty) return;

    try {
      final service = ref.read(prescriptionServiceProvider);
      await service.updatePrescriptionStatus(
        prescriptionId: widget.prescription.id,
        status: PrescriptionStatus.rejected,
        patientResponse: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối đơn thuốc'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRequestEdit() async {
    // Kiểm tra nếu đã yêu cầu >= 3 lần
    if (widget.prescription.modificationRequestCount >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn đã yêu cầu chỉnh sửa 3 lần. Vui lòng gọi video với bác sĩ để giải quyết.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final reason = await _showReasonDialog(
      title: 'Yêu cầu chỉnh sửa',
      hint: 'Vui lòng cho biết nội dung cần chỉnh sửa',
    );
    if (reason == null || reason.trim().isEmpty) return;

    try {
      final service = ref.read(prescriptionServiceProvider);
      final newCount = widget.prescription.modificationRequestCount + 1;

      await service.updatePrescriptionStatus(
        prescriptionId: widget.prescription.id,
        status: PrescriptionStatus.modificationRequested,
        patientResponse: reason,
        modificationRequestCount: newCount,
        requiresVideoCall: newCount >= 3, // Đánh dấu cần call nếu >= 3
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (newCount >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã gửi yêu cầu. Bạn cần gọi video với bác sĩ để giải quyết vấn đề này.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã gửi yêu cầu chỉnh sửa đến bác sĩ'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _showReasonDialog({
    required String title,
    required String hint,
  }) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(title: title, hint: hint),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prescription = widget.prescription;
    final statusColor = _getStatusColor();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppDimensions.borderRadiusLarge,
        side: BorderSide(
          color: prescription.status == PrescriptionStatus.pendingPatientReview
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: AppDimensions.paddingAllMedium,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(statusColor),
                  const SizedBox(height: 12),
                  _buildBasicInfo(),
                  if (_isExpanded) ...[
                    const Divider(height: 24),
                    _buildDetailedInfo(),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bác sĩ: ${prescription.doctorName}',
                        style: AppTextStyles.caption,
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.isPatientView &&
              prescription.status == PrescriptionStatus.pendingPatientReview)
            _buildPatientActionButtons(),
          if (widget.isPatientView &&
              prescription.requiresVideoCall &&
              prescription.status == PrescriptionStatus.modificationRequested)
            _buildVideoCallRequired(),
          if (!widget.isPatientView &&
              prescription.status == PrescriptionStatus.modificationRequested &&
              !prescription.requiresVideoCall)
            _buildDoctorEditButton(),
          if (prescription.patientResponse != null) _buildPatientResponse(),
          if (prescription.needsRenewalNotification() &&
              prescription.status == PrescriptionStatus.active)
            _buildRenewalNotification(),
        ],
      ),
    );
  }

  Widget _buildHeader(Color statusColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: AppDimensions.borderRadiusMedium,
          ),
          child: Icon(_getStatusIcon(), color: statusColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.prescription.medicationName,
                style: AppTextStyles.body1Bold,
              ),
              if (widget.prescription.concentration != null)
                Text(
                  widget.prescription.concentration!,
                  style: AppTextStyles.body2Secondary,
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.prescription.status.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          Icons.medical_services,
          'Liều dùng',
          widget.prescription.dosage,
        ),
        const SizedBox(height: 6),
        _buildInfoRow(
          Icons.local_hospital,
          'Đường dùng',
          widget.prescription.route,
        ),
        if (widget.prescription.timing != null) ...[
          const SizedBox(height: 6),
          _buildInfoRow(
            Icons.access_time,
            'Thời điểm',
            widget.prescription.timing!,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailedInfo() {
    final prescription = widget.prescription;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prescription.quantity != null)
          _buildInfoRow(Icons.inventory_2, 'Số lượng', prescription.quantity!),
        if (prescription.specialInstructions != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  prescription.specialInstructions!,
                  style: AppTextStyles.caption.copyWith(color: Colors.orange),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        _buildInfoRow(
          Icons.calendar_today,
          'Thời gian',
          '${DateFormat('dd/MM/yyyy').format(prescription.startDate)} - ${DateFormat('dd/MM/yyyy').format(prescription.endDate)}',
        ),
        const SizedBox(height: 6),
        _buildInfoRow(
          Icons.timer,
          'Thời hạn',
          '${prescription.durationDays} ngày',
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text('$label: ', style: AppTextStyles.caption),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientActionButtons() {
    // Kiểm tra xem có phải là lần chỉnh sửa cuối cùng sau video call không
    final isAfterVideoCall = widget.prescription.modificationRequestCount >= 3;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _handleReject,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Từ chối'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          // Chỉ hiện nút "Chỉnh sửa" nếu chưa qua video call
          if (!isAfterVideoCall) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleRequestEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Chỉnh sửa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleAccept,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Chấp nhận'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCallRequired() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.video_call, size: 24, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cần gọi video với bác sĩ',
                  style: AppTextStyles.body2.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bạn đã yêu cầu chỉnh sửa 3 lần. Vui lòng gọi video với bác sĩ ${widget.prescription.doctorName} để giải quyết vấn đề.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _handleVideoCallAndResolve(),
            icon: const Icon(Icons.video_call, size: 20),
            label: const Text('Gọi video với bác sĩ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVideoCallAndResolve() async {
    // Lấy thông tin người dùng hiện tại
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xác định người dùng'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Xác định người gọi và người nhận
    // Nếu currentUser là patient thì gọi đến doctor, ngược lại
    final callerId = currentUser.uid;
    final calleeId = callerId == widget.prescription.patientId
        ? widget.prescription.doctorId
        : widget.prescription.patientId;

    // Tạo channel name giống như trong chat
    final chatVm = ref.read(chatThreadViewModelProvider);
    final channelName = chatVm.buildChannelName(callerId, calleeId);

    // Tạo call session trong Firestore
    final callVm = ref.read(callViewModelProvider);
    try {
      final callId = await callVm.startOutgoingCall(
        callerId: callerId,
        calleeId: calleeId,
        channelName: channelName,
      );

      if (!mounted) return;

      // Navigate đến PrescriptionCallWrapper và đợi kết quả
      final callCompleted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              PrescriptionCallWrapper(callId: callId, channelName: channelName),
        ),
      );

      // Chỉ hiện dialog nếu call hoàn thành (true), không hiện nếu bị hủy (false/null)
      if (callCompleted != true || !mounted) return;

      final resolved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận'),
          content: const Text(
            'Sau cuộc gọi với bác sĩ, vấn đề của bạn đã được giải quyết chưa?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Chưa giải quyết'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Đã giải quyết'),
            ),
          ],
        ),
      );

      if (resolved == null) return;

      final service = ref.read(prescriptionServiceProvider);

      if (resolved) {
        // Nếu giải quyết được → cho phép bác sĩ chỉnh sửa lần cuối
        await service.updatePrescriptionStatus(
          prescriptionId: widget.prescription.id,
          status: PrescriptionStatus.modificationRequested,
          patientResponse:
              'Đã thảo luận qua video call. Đồng ý cho bác sĩ chỉnh sửa lần cuối.',
          requiresVideoCall:
              false, // Tắt yêu cầu video call để bác sĩ có thể sửa
        );

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã gửi yêu cầu cho bác sĩ chỉnh sửa lần cuối.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Nếu không giải quyết được → từ chối
        await service.updatePrescriptionStatus(
          prescriptionId: widget.prescription.id,
          status: PrescriptionStatus.rejected,
          patientResponse:
              'Vấn đề chưa được giải quyết sau cuộc gọi video. Từ chối chỉ định.',
          requiresVideoCall: false,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã từ chối chỉ định thuốc.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDoctorEditButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bệnh nhân yêu cầu chỉnh sửa',
              style: AppTextStyles.caption.copyWith(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CreatePrescriptionBottomSheet(
                  patientId: widget.prescription.patientId,
                  existingPrescription: widget.prescription,
                ),
              );
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Chỉnh sửa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientResponse() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.message, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phản hồi của bệnh nhân:',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.prescription.patientResponse!,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenewalNotification() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notification_important,
            size: 20,
            color: Colors.amber[800],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đơn thuốc sắp hết hạn. Bạn có muốn yêu cầu bác sĩ gia hạn không?',
              style: AppTextStyles.caption.copyWith(color: Colors.amber[900]),
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement renewal request
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chức năng gia hạn đang phát triển'),
                ),
              );
            },
            child: const Text('Gia hạn'),
          ),
        ],
      ),
    );
  }
}

// Separate StatefulWidget for dialog to manage TextEditingController lifecycle
class _ReasonDialog extends StatefulWidget {
  final String title;
  final String hint;

  const _ReasonDialog({required this.title, required this.hint});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
