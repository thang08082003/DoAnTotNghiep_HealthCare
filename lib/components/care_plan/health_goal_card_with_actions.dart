import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/care_plan_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/care_plan_service.dart';
import '../../screens/patients/widgets/edit_health_goal_bottom_sheet.dart';
import '../../screens/call/health_goal_call_wrapper.dart';
import '../../viewmodels/call/call_view_model.dart';
import 'health_goal_item_widget.dart';

/// Widget hiển thị health goal với action buttons
/// Tương tự PrescriptionCard với approve/reject/edit workflow
class HealthGoalCardWithActions extends ConsumerWidget {
  final HealthGoal goal;
  final bool isPatientView; // true if patient viewing, false if doctor viewing

  const HealthGoalCardWithActions({
    super.key,
    required this.goal,
    this.isPatientView = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goal.type.color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Goal content (without outer decoration)
          HealthGoalItemWidget(goal: goal, showDecoration: false),

          // Doctor view: show edit button when patient requests modification
          if (!isPatientView &&
              goal.status == HealthGoalStatus.modificationRequested) ...[
            const SizedBox(height: 16),
            _buildDoctorEditButton(context),
          ],

          // Patient view: action buttons ONLY when pending (not when modification requested)
          if (isPatientView &&
              goal.status == HealthGoalStatus.pendingPatientReview) ...[
            const SizedBox(height: 16),
            _buildActionButtons(context, ref),
          ],

          // Patient view: waiting message when modification requested
          if (isPatientView &&
              goal.status == HealthGoalStatus.modificationRequested) ...[
            const SizedBox(height: 16),
            _buildWaitingMessage(),
          ],

          // Status badge cho các trạng thái khác
          if (goal.status == HealthGoalStatus.approvedByPatient ||
              goal.status == HealthGoalStatus.active) ...[
            const SizedBox(height: 16),
            _buildApprovedBadge(),
          ],

          if (goal.status == HealthGoalStatus.rejected) ...[
            const SizedBox(height: 16),
            _buildRejectedBadge(),
          ],
        ],
      ),
    );
  }

  Widget _buildDoctorEditButton(BuildContext context) {
    // Kiểm tra xem có phải lần sửa cuối sau video call không
    final isFinalEditAfterCall = goal.isFinalEdit;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFinalEditAfterCall
            ? Colors.red.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFinalEditAfterCall
              ? Colors.red.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isFinalEditAfterCall ? Icons.video_call : Icons.feedback,
                color: isFinalEditAfterCall
                    ? Colors.red.shade700
                    : Colors.orange.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFinalEditAfterCall
                      ? 'CHỈNH SỬA LẦN CUỐI sau video call (${goal.modificationRequestCount}/3)'
                      : 'Bệnh nhân yêu cầu chỉnh sửa (${goal.modificationRequestCount}/3)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isFinalEditAfterCall
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (goal.patientResponse != null) ...[
            const SizedBox(height: 8),
            Text(
              'Phản hồi: ${goal.patientResponse}',
              style: TextStyle(
                fontSize: 13,
                color: isFinalEditAfterCall
                    ? Colors.red.shade900
                    : Colors.orange.shade900,
                fontWeight: isFinalEditAfterCall
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
          ],
          if (isFinalEditAfterCall) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ Sau khi chỉnh sửa, bệnh nhân CHỈ có thể chấp nhận hoặc từ chối, không được yêu cầu sửa nữa.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    EditHealthGoalBottomSheet(existingGoal: goal),
              );
            },
            icon: const Icon(Icons.edit, size: 18),
            label: Text(
              isFinalEditAfterCall
                  ? 'Chỉnh sửa lần cuối'
                  : 'Chỉnh sửa mục tiêu',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFinalEditAfterCall
                  ? Colors.red.shade600
                  : AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    // Hiển thị Accept/Reject/Edit buttons
    // Hàm này chỉ được gọi khi status = pendingPatientReview
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bác sĩ đã chỉnh sửa mục tiêu. Vui lòng xem xét:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Accept button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleAccept(context, ref),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Chấp nhận'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Reject button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleReject(context, ref),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Từ chối'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          // Chỉ hiển thị nút yêu cầu chỉnh sửa nếu count < 3
          if (goal.modificationRequestCount < 3) ...[
            const SizedBox(height: 8),
            // Edit request button
            OutlinedButton.icon(
              onPressed: () => _handleRequestEdit(context, ref),
              icon: const Icon(Icons.edit, size: 18),
              label: Text(
                goal.modificationRequestCount > 0
                    ? 'Yêu cầu chỉnh sửa lại (${goal.modificationRequestCount}/3)'
                    : 'Yêu cầu chỉnh sửa',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                side: const BorderSide(color: AppColors.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang chờ bác sĩ chỉnh sửa',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bác sĩ sẽ cập nhật mục tiêu theo yêu cầu của bạn. Bạn sẽ có thể xem xét lại sau khi bác sĩ chỉnh sửa.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                ),
                if (goal.patientResponse != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Yêu cầu của bạn: ${goal.patientResponse}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
          const SizedBox(width: 8),
          Text(
            'Bạn đã chấp nhận mục tiêu này',
            style: TextStyle(
              fontSize: 13,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn đã từ chối mục tiêu này',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (goal.patientResponse != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Lý do: ${goal.patientResponse}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(carePlanServiceProvider);
      await service.updateHealthGoal(goal.id, {
        'status': HealthGoalStatus.approvedByPatient.value,
        'updatedAt': DateTime.now(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã chấp nhận mục tiêu')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(title: 'Lý do từ chối'),
    );

    if (reason == null || reason.trim().isEmpty) return;

    try {
      final service = ref.read(carePlanServiceProvider);
      await service.updateHealthGoal(goal.id, {
        'status': HealthGoalStatus.rejected.value,
        'patientResponse': reason,
        'updatedAt': DateTime.now(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã từ chối mục tiêu')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _handleRequestEdit(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(title: 'Nội dung cần chỉnh sửa'),
    );

    if (reason == null || reason.trim().isEmpty) return;

    try {
      final service = ref.read(carePlanServiceProvider);
      final newCount = goal.modificationRequestCount + 1;

      await service.updateHealthGoal(goal.id, {
        'status': HealthGoalStatus.modificationRequested.value,
        'patientResponse': reason,
        'modificationRequestCount': newCount,
        'requiresVideoCall': newCount >= 3,
        'updatedAt': DateTime.now(),
      });

      if (context.mounted) {
        if (newCount >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã gửi yêu cầu. Vui lòng liên hệ bác sĩ qua video call.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi yêu cầu chỉnh sửa')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _handleVideoCall(BuildContext context, WidgetRef ref) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Tạo channel name duy nhất
      final channelName =
          'health_goal_${goal.id}_${DateTime.now().millisecondsSinceEpoch}';

      // Tạo cuộc gọi
      final callViewModel = ref.read(callViewModelProvider);
      final callId = await callViewModel.startOutgoingCall(
        callerId: currentUser.uid,
        calleeId: goal.doctorId ?? '',
        channelName: channelName,
      );

      if (!context.mounted) return;

      // Navigate đến wrapper - wrapper sẽ quản lý video call và dialog
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) =>
              HealthGoalCallWrapper(callId: callId, channelName: channelName),
        ),
      );

      // Xử lý kết quả
      if (!context.mounted) return;
      if (result == null || result['cancelled'] == true) {
        // Cuộc gọi bị hủy hoặc không kết nối
        return;
      }

      final resolved = result['resolved'] as bool?;
      if (resolved == null) return;

      if (!resolved) {
        // Chưa giải quyết → Từ chối mục tiêu
        await _rejectAfterVideoCall(context, ref);
      } else {
        // Đã giải quyết → Thông báo chờ bác sĩ chỉnh sửa lần cuối
        await _markForFinalEdit(context, ref);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tạo cuộc gọi: $e')));
    }
  }

  Future<void> _rejectAfterVideoCall(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await CarePlanService().updateHealthGoal(goal.id, {
        'status': HealthGoalStatus.rejected.value,
        'patientResponse':
            'Từ chối sau cuộc gọi video - vấn đề chưa được giải quyết',
        'updatedAt': DateTime.now(),
      });

      // Delay nhỏ để đảm bảo Firestore đã propagate changes
      await Future.delayed(const Duration(milliseconds: 300));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã từ chối mục tiêu này'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _markForFinalEdit(BuildContext context, WidgetRef ref) async {
    try {
      // Đánh dấu là đang chờ bác sĩ chỉnh sửa lần cuối
      // Thêm flag để bệnh nhân chỉ có thể accept/reject (không request edit nữa)
      await CarePlanService().updateHealthGoal(goal.id, {
        'status': HealthGoalStatus.modificationRequested.value,
        'patientResponse':
            'Đã trao đổi qua video call - Chờ bác sĩ chỉnh sửa lần cuối',
        'isFinalEdit': true, // Flag mới để đánh dấu lần sửa cuối
        'updatedAt': DateTime.now(),
      });

      // Delay nhỏ để đảm bảo Firestore đã propagate changes
      await Future.delayed(const Duration(milliseconds: 300));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã ghi nhận. Chờ bác sĩ chỉnh sửa lần cuối, sau đó bạn sẽ chỉ có thể chấp nhận hoặc từ chối.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }
}

// Dialog nhập lý do
class _ReasonDialog extends StatefulWidget {
  final String title;

  const _ReasonDialog({required this.title});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

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
        decoration: const InputDecoration(
          hintText: 'Nhập lý do...',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
