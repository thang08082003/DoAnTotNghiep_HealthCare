import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../components/buttons/logout_button.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../viewmodels/profile/patient_profile_view_model.dart';
import '../../viewmodels/profile/doctor_profile_view_model.dart';
import '../../viewmodels/profile/avatar_view_model.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import 'health_connect_screen.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/user_model.dart';
import '../help/help_screen.dart';
import 'change_password_screen.dart';

class ProfileContent extends ConsumerWidget {
  const ProfileContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(currentUserProvider);

    return userAsyncValue.when(
      data: (user) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _AvatarPicker(
                    avatarUrl: user?.avatarUrl,
                    uid: user?.uid,
                    onUpdated: () => ref.invalidate(currentUserProvider),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Chưa cập nhật',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Chưa cập nhật',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Patient-specific info card
            if ((user?.isPatient ?? false)) ...[
              const SizedBox(height: 16),
              _PatientInfoCard(
                user: user!,
                onEdit: () {
                  ref.invalidate(currentUserProvider);
                },
              ),
            ],
            // Doctor-specific info card
            if ((user?.isDoctor ?? false)) ...[
              const SizedBox(height: 16),
              _DoctorInfoCard(
                doctor: user as DoctorModel,
                onEdit: () {
                  ref.invalidate(currentUserProvider);
                },
              ),
            ],
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                    'Cài đặt',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (user?.isPatient == true)
                    ListTile(
                      leading: const Icon(
                        Icons.favorite,
                        color: AppColors.primaryColor,
                      ),
                      title: const Text('Kết nối Health Connect'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GoogleFitConnectScreen(),
                          ),
                        );
                      },
                    ),
                  // Doctor-specific settings item removed as requested
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.security,
                      color: AppColors.primaryColor,
                    ),
                    title: const Text('Đổi mật khẩu'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.help,
                      color: AppColors.primaryColor,
                    ),
                    title: const Text('Trợ giúp'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Consumer(
                builder: (context, ref, child) {
                  final authState = ref.watch(authProvider);
                  return LogoutButton(
                    isLoading: authState.isLoading,
                    onPressed: () async {
                      try {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          AppRouter.pushLogin(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi đăng xuất: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      loading: () => const LoadingWidget(),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Lỗi: $error'),
          ],
        ),
      ),
    );
  }
}

class _PatientInfoCard extends ConsumerWidget {
  final dynamic user; // UserModel
  final VoidCallback onEdit;

  const _PatientInfoCard({required this.user, required this.onEdit});

  String _displayOrNA(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Chưa cập nhật' : v.trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = user.phone as String?;
    final gender = user.gender as String?;
    final medicalHistory = user.medicalHistory as String?;
    final age = user.age as int?;
    final diseaseFocusEnum =
        (user as dynamic).diseaseFocusEnum as DiseaseFocus?;
    final diseaseFocusText = diseaseFocusEnum?.displayName ?? 'Chưa cập nhật';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thông tin bệnh nhân',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 8),
          _editableRow(
            context,
            label: 'Số điện thoại',
            value: _displayOrNA(phone),
            keyboardType: TextInputType.phone,
            onSave: (val) async {
              final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.length != 10) throw 'Số điện thoại phải có đúng 10 số';
              await ref
                  .read(patientProfileViewModelProvider(user.uid).notifier)
                  .updatePhone(digits);
              onEdit();
            },
          ),
          const Divider(height: 24),
          _editableRow(
            context,
            label: 'Tuổi',
            value: age == null ? 'Chưa cập nhật' : '$age',
            keyboardType: TextInputType.number,
            onSave: (val) async {
              final parsed = int.tryParse(val.trim());
              if (parsed == null || parsed < 0 || parsed > 120) {
                throw 'Tuổi không hợp lệ (0 - 120)';
              }
              await ref
                  .read(patientProfileViewModelProvider(user.uid).notifier)
                  .updateAge(parsed);
              onEdit();
            },
          ),
          const Divider(height: 24),
          // Bệnh theo dõi (Disease Focus) - chọn từ enum
          InkWell(
            onTap: () async {
              final selected = await _showDiseaseFocusSheet(
                context,
                current: diseaseFocusEnum,
              );
              if (selected == null) return;
              try {
                if (selected == _DiseaseFocusDialogResult.clear) {
                  await ref
                      .read(patientProfileViewModelProvider(user.uid).notifier)
                      .updateDiseaseFocus(null);
                } else if (selected is DiseaseFocus) {
                  await ref
                      .read(patientProfileViewModelProvider(user.uid).notifier)
                      .updateDiseaseFocus(selected.value);
                }
                onEdit();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bệnh theo dõi',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    diseaseFocusText,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          // Giới tính: hiển thị chỉ đọc (không cho sửa theo yêu cầu)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Giới tính',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _displayOrNA(gender),
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            'Tiền sử bệnh (tối đa 150 ký tự)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final current = _displayOrNA(medicalHistory);
              final result = await _showEditBottomSheet(
                context,
                title: 'Tiền sử bệnh (tối đa 150 ký tự)',
                initialValue: current == 'Chưa cập nhật' ? '' : current,
                maxLines: 5,
                charLimit: 150,
              );
              if (result == null) return;
              final trimmed = result.trim();
              if (trimmed.length > 150) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vượt quá 150 ký tự')),
                  );
                }
                return;
              }
              await ref
                  .read(patientProfileViewModelProvider(user.uid).notifier)
                  .updateMedicalHistory(trimmed);
              onEdit();
            },
            child: Text(
              _displayOrNA(medicalHistory),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableRow(
    BuildContext context, {
    required String label,
    required String value,
    required Future<void> Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return InkWell(
      onTap: () async {
        final current = value == 'Chưa cập nhật' ? '' : value;
        final result = await _showEditBottomSheet(
          context,
          title: label,
          initialValue: current,
          keyboardType: keyboardType,
        );
        if (result == null) return;
        try {
          await onSave(result);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog helpers for Disease Focus selection

class _DoctorInfoCard extends ConsumerWidget {
  final DoctorModel doctor;
  final VoidCallback onEdit;

  const _DoctorInfoCard({required this.doctor, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specialty = doctor.specialty.vietnameseName;
    final years = doctor.yearsExperience;

    final description =
        (doctor.description == null || doctor.description!.isEmpty)
        ? 'Chưa cập nhật'
        : doctor.description!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thông tin bác sĩ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 8),
          _row('Chuyên khoa', specialty),
          const Divider(height: 24),
          // Giới tính (không chỉnh sửa)
          if (doctor.gender != null)
            _row(
              'Giới tính',
              doctor.gender!.isEmpty ? 'Chưa cập nhật' : doctor.gender!,
            )
          else
            _row('Giới tính', 'Chưa cập nhật'),
          const Divider(height: 24),
          // Số điện thoại (có thể chỉnh sửa, giới hạn 10 số)
          _editableRow(
            context,
            label: 'Số điện thoại',
            value: (doctor.phone == null || doctor.phone!.isEmpty)
                ? 'Chưa cập nhật'
                : doctor.phone!,
            keyboardType: TextInputType.phone,
            onSave: (val) async {
              final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.isNotEmpty && digits.length != 10) {
                throw 'Số điện thoại phải có đúng 10 số';
              }
              await ref
                  .read(doctorProfileViewModelProvider(doctor.uid).notifier)
                  .updatePhone(digits.isEmpty ? null : digits);
              onEdit();
            },
          ),
          const Divider(height: 24),
          _editableRow(
            context,
            label: 'Kinh nghiệm',
            value: years != null ? '$years năm' : 'Chưa cập nhật',
            keyboardType: TextInputType.number,
            onSave: (val) async {
              final onlyNumber = val.replaceAll(RegExp(r'[^0-9]'), '');
              final parsed = int.tryParse(onlyNumber);
              if (parsed == null) throw 'Số năm không hợp lệ';
              if (parsed >= 45) throw 'Kinh nghiệm phải < 45 năm';
              await ref
                  .read(doctorProfileViewModelProvider(doctor.uid).notifier)
                  .updateYearsExperience(parsed);
              onEdit();
            },
          ),
          const Divider(height: 24),
          // Mô tả (hiển thị dạng block giống Tiền sử bệnh của bệnh nhân)
          const Text(
            'Mô tả (tối đa 150 ký tự)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final current = description.trim();
              final result = await _showEditBottomSheet(
                context,
                title: 'Mô tả (tối đa 150 ký tự)',
                initialValue: current == 'Chưa cập nhật' ? '' : current,
                maxLines: 6,
                charLimit: 150,
              );
              if (result == null) return;
              final trimmed = result.trim();
              await ref
                  .read(doctorProfileViewModelProvider(doctor.uid).notifier)
                  .updateDescription(trimmed.isEmpty ? null : trimmed);
              onEdit();
            },
            child: Text(
              description.trim().isEmpty ? 'Chưa cập nhật' : description,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

enum _DiseaseFocusDialogResult { clear }

// ===== Top-level reusable helpers for inline field editing dialogs =====

Future<String?> _showEditBottomSheet(
  BuildContext context, {
  required String title,
  String initialValue = '',
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  int? charLimit,
}) async {
  final ctl = TextEditingController(text: initialValue);
  final limit = charLimit ?? (maxLines > 1 ? 1000 : null);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: StatefulBuilder(
        builder: (ctx, setState) {
          final currentLength = ctl.text.characters.length;
          final content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctl,
                keyboardType: keyboardType,
                maxLines: maxLines,
                minLines: maxLines > 1 ? (maxLines / 2).ceil() : 1,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  counterText: limit != null ? '$currentLength/$limit' : null,
                ),
              ),
              if (limit != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Tối đa $limit ký tự',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (limit != null && ctl.text.characters.length > limit) {
                        return;
                      }
                      Navigator.of(ctx).pop(ctl.text);
                    },
                    child: const Text('Lưu'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
          return SafeArea(child: content);
        },
      ),
    ),
  );
}

Future<Object?> _showDiseaseFocusSheet(
  BuildContext context, {
  DiseaseFocus? current,
}) {
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final content = Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn bệnh theo dõi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.clear, color: AppColors.textSecondary),
              title: const Text('Xoá lựa chọn'),
              onTap: () =>
                  Navigator.of(ctx).pop(_DiseaseFocusDialogResult.clear),
            ),
            const Divider(height: 0),
            SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...DiseaseFocus.values.map((f) {
                    final selected = f == current;
                    return ListTile(
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected
                            ? AppColors.primaryColor
                            : AppColors.textSecondary,
                      ),
                      title: Text(f.displayName),
                      onTap: () => Navigator.of(ctx).pop(f),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      );
      return SafeArea(child: content);
    },
  );
}

// (Đã thay bằng _showEditBottomSheet)

Widget _editableRow(
  BuildContext context, {
  required String label,
  required String value,
  required Future<void> Function(String) onSave,
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  int? charLimit,
}) {
  return InkWell(
    onTap: () async {
      final current = value == 'Chưa cập nhật' ? '' : value;
      final result = await _showEditBottomSheet(
        context,
        title: label,
        initialValue: current,
        keyboardType: keyboardType,
        maxLines: maxLines,
        charLimit: charLimit,
      );
      if (result == null) return;
      try {
        await onSave(result);
        // Success feedback
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi')));
      } catch (e) {
        // Error feedback (e.g., Kinh nghiệm phải < 45 năm)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    },
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

// (Top-level gender row helper removed to avoid duplicate; using the one inside _PatientInfoCard)

// ===== Avatar Picker Widget =====
class _AvatarPicker extends ConsumerStatefulWidget {
  final String? avatarUrl;
  final String? uid;
  final VoidCallback onUpdated;

  const _AvatarPicker({
    required this.avatarUrl,
    required this.uid,
    required this.onUpdated,
  });

  @override
  ConsumerState<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<_AvatarPicker> {
  bool _uploading = false;
  String? _overrideUrl; // Hiển thị tạm thời avatar mới ngay lập tức

  Future<void> _pickAndUpload() async {
    if (widget.uid == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploading = true);
      final ext = picked.name.split('.').last.toLowerCase();
      final bytes = await picked.readAsBytes();

      final vm = ref.read(avatarViewModelProvider);
      final url = await vm.uploadAndSetAvatar(
        uid: widget.uid!,
        bytes: bytes,
        fileExt: ext,
      );

      if (mounted) {
        setState(() {
          _uploading = false;
          if (url != null) _overrideUrl = url;
        });
        if (url != null) {
          widget.onUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ảnh đại diện đã được cập nhật')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi cập nhật ảnh: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = _overrideUrl ?? widget.avatarUrl;
    final hasAvatar = (effectiveUrl != null && effectiveUrl.isNotEmpty);
    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
            // Thêm query tạm thời để chắc chắn bypass cache nếu vẫn cùng URL
            backgroundImage: hasAvatar
                ? NetworkImage(
                    hasAvatar
                        ? '$effectiveUrl?v=${DateTime.now().millisecondsSinceEpoch}'
                        : effectiveUrl,
                  )
                : null,
            child: !hasAvatar
                ? const Icon(
                    Icons.person,
                    size: 40,
                    color: AppColors.primaryColor,
                  )
                : null,
          ),
          if (_uploading)
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(),
            )
          else
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
