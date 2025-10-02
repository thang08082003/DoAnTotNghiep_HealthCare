import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/buttons/logout_button.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import 'edit_patient_profile_screen.dart';
import 'smart_watch_connect_screen.dart';
import '../../data/models/doctor_model.dart';
import 'edit_doctor_profile_screen.dart';

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
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.primaryColor,
                    ),
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
                onEdit: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditPatientProfileScreen(),
                    ),
                  );
                  if (result == true) {
                    ref.invalidate(currentUserProvider);
                  }
                },
              ),
            ],
            // Doctor-specific info card
            if ((user?.isDoctor ?? false)) ...[
              const SizedBox(height: 16),
              _DoctorInfoCard(
                doctor: user as DoctorModel,
                onEdit: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditDoctorProfileScreen(),
                    ),
                  );
                  if (result == true) {
                    ref.invalidate(currentUserProvider);
                  }
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
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Chỉnh sửa'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('Số điện thoại', _displayOrNA(phone)),
          const Divider(height: 24),
          _row('Tuổi', age == null ? 'Chưa cập nhật' : '$age'),
          const Divider(height: 24),
          _row('Giới tính', _displayOrNA(gender)),
          const Divider(height: 24),
          const Text(
            'Tiền sử bệnh',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _displayOrNA(medicalHistory),
            style: const TextStyle(color: AppColors.textSecondary),
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

class _DoctorInfoCard extends StatelessWidget {
  final DoctorModel doctor;
  final VoidCallback onEdit;

  const _DoctorInfoCard({required this.doctor, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final specialty = doctor.specialty.vietnameseName;
    final years = doctor.yearsExperience;
    final email = doctor.email;

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
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Chỉnh sửa'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('Email', email),
          const Divider(height: 24),
          _row('Chuyên khoa', specialty),
          const Divider(height: 24),
          _row('Kinh nghiệm', years != null ? '$years năm' : 'Chưa cập nhật'),
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
