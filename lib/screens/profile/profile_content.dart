import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../data/config/media_upload_config.dart';
import '../../data/services/media_upload_service.dart';
import '../../components/buttons/logout_button.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
// Removed old full-screen editors; fields are now edited inline via dialogs
import 'smart_watch_connect_screen.dart';
import '../../data/models/doctor_model.dart';

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
                        Icons.watch,
                        color: AppColors.primaryColor,
                      ),
                      title: const Text('Kết nối Smart Watch'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SmartWatchConnectScreen(),
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
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.help,
                      color: AppColors.primaryColor,
                    ),
                    title: const Text('Trợ giúp'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
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

class _PatientInfoCard extends StatelessWidget {
  final dynamic user; // UserModel
  final VoidCallback onEdit;

  const _PatientInfoCard({required this.user, required this.onEdit});

  String _displayOrNA(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Chưa cập nhật' : v.trim();

  @override
  Widget build(BuildContext context) {
    final phone = user.phone as String?;
    final gender = user.gender as String?;
    final medicalHistory = user.medicalHistory as String?;
    final age = user.age as int?;

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
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'phone': val.trim()});
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
              if (parsed == null) throw 'Tuổi không hợp lệ';
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'age': parsed});
              onEdit();
            },
          ),
          const Divider(height: 24),
          _editableGenderRow(
            context,
            label: 'Giới tính',
            value: _displayOrNA(gender),
            onSave: (val) async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'gender': val});
              onEdit();
            },
          ),
          const Divider(height: 24),
          const Text(
            'Tiền sử bệnh',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final current = _displayOrNA(medicalHistory);
              final result = await _showEditDialog(
                context,
                title: 'Tiền sử bệnh',
                initialValue: current == 'Chưa cập nhật' ? '' : current,
                maxLines: 5,
              );
              if (result == null) return;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'medicalHistory': result.trim()});
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
        final result = await _showEditDialog(
          context,
          title: label,
          initialValue: current,
          keyboardType: keyboardType,
        );
        if (result == null) return;
        await onSave(result);
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

  Widget _editableGenderRow(
    BuildContext context, {
    required String label,
    required String value,
    required Future<void> Function(String) onSave,
  }) {
    return InkWell(
      onTap: () async {
        final selection = await showDialog<String>(
          context: context,
          builder: (ctx) {
            String current = (value == 'Chưa cập nhật') ? '' : value;
            final options = ['Nam', 'Nữ', 'Khác'];
            return AlertDialog(
              title: Text(label),
              content: StatefulBuilder(
                builder: (context, setState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options
                      .map(
                        (opt) => RadioListTile<String>(
                          title: Text(opt),
                          value: opt,
                          groupValue: current,
                          onChanged: (v) => setState(() => current = v ?? ''),
                        ),
                      )
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Huỷ'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(current),
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
        if (selection == null) return;
        await onSave(selection);
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

  Future<String?> _showEditDialog(
    BuildContext context, {
    required String title,
    String initialValue = '',
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) async {
    final ctl = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _DoctorInfoCard extends StatelessWidget {
  final DoctorModel doctor;
  final VoidCallback onEdit;

  const _DoctorInfoCard({required this.doctor, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final specialty = doctor.specialty.vietnameseName;
    final years = doctor.yearsExperience;
    final email = doctor.email;
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
          _editableRow(
            context,
            label: 'Email',
            value: email,
            keyboardType: TextInputType.emailAddress,
            onSave: (val) async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(doctor.uid)
                  .update({'email': val.trim()});
              onEdit();
            },
          ),
          const Divider(height: 24),
          _row('Chuyên khoa', specialty),
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
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(doctor.uid)
                  .update({'yearsExperience': parsed});
              onEdit();
            },
          ),
          const Divider(height: 24),
          // Mô tả (hiển thị dạng block giống Tiền sử bệnh của bệnh nhân)
          const Text(
            'Mô tả',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final current = description.trim();
              final result = await _showEditDialog(
                context,
                title: 'Mô tả',
                initialValue: current == 'Chưa cập nhật' ? '' : current,
                maxLines: 8,
                charLimit: 1000,
              );
              if (result == null) return;
              final trimmed = result.trim();
              if (trimmed.isEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(doctor.uid)
                    .update({'description': FieldValue.delete()});
              } else {
                if (trimmed.length > 1000) {
                  // Guard although dialog prevents oversave
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mô tả quá dài (tối đa 1000 ký tự)'),
                    ),
                  );
                  return;
                }
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(doctor.uid)
                    .update({'description': trimmed});
              }
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

// ===== Top-level reusable helpers for inline field editing dialogs =====

Future<String?> _showEditDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  int? charLimit,
}) async {
  final ctl = TextEditingController(text: initialValue);
  final limit = charLimit ?? (maxLines > 1 ? 1000 : null);
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final currentLength = ctl.text.characters.length;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.maxFinite,
                child: TextField(
                  controller: ctl,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  minLines: maxLines > 1 ? (maxLines / 2).ceil() : 1,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    counterText: limit != null
                        ? '${currentLength.toString()}/${limit.toString()}'
                        : null,
                  ),
                ),
              ),
              if (limit != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Tối đa $limit ký tự',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () {
                if (limit != null && ctl.text.characters.length > limit) {
                  return; // Do nothing if over limit
                }
                Navigator.of(ctx).pop(ctl.text);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    ),
  );
}

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
      final result = await _showEditDialog(
        context,
        title: label,
        initialValue: current,
        keyboardType: keyboardType,
        maxLines: maxLines,
        charLimit: charLimit,
      );
      if (result == null) return;
      await onSave(result);
      // Show quick feedback
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi')));
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
class _AvatarPicker extends StatefulWidget {
  final String? avatarUrl;
  final String? uid;
  final VoidCallback onUpdated;

  const _AvatarPicker({
    required this.avatarUrl,
    required this.uid,
    required this.onUpdated,
  });

  @override
  State<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<_AvatarPicker> {
  bool _uploading = false;

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
      final path = 'avatars/${widget.uid}/profile.${ext}';
      final fileData = await picked.readAsBytes();

      String url;
      if (MediaUploadConfig.provider == MediaUploadProvider.firebaseStorage) {
        final ref = FirebaseStorage.instance.ref().child(path);
        final metadata = SettableMetadata(
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          cacheControl: 'public, max-age=86400',
        );
        await ref.putData(fileData, metadata);
        url = await ref.getDownloadURL();
      } else {
        url = await MediaUploadService.uploadAvatar(
          uid: widget.uid!,
          data: fileData,
          fileExt: (ext == 'png' || ext == 'jpg' || ext == 'jpeg')
              ? (ext == 'jpg' ? 'jpeg' : ext)
              : 'jpeg',
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({'avatarUrl': url});

      if (mounted) {
        setState(() => _uploading = false);
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ảnh đại diện đã được cập nhật')),
        );
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
    final hasAvatar =
        (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty);
    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
            backgroundImage: hasAvatar ? NetworkImage(widget.avatarUrl!) : null,
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
