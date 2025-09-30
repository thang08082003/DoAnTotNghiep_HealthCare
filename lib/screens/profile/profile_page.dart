import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/base_page/base_page_scaffold.dart';
import '../../components/buttons/logout_button.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';

class ProfilePage extends BasePage {
  const ProfilePage({
    super.key,
    required super.userRole,
  }) : super(
          title: 'Hồ sơ',
        );

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends BasePageState<ProfilePage> {
  @override
  List<Widget> buildPages() {
    return [_buildProfileContent()];
  }

  @override
  void onNavigationTap(int index) {
    // Navigation handled by HomePage
  }

  Widget _buildProfileContent() {
    return Consumer(
      builder: (context, ref, child) {
        final userAsyncValue = ref.watch(currentUserProvider);
        
        return userAsyncValue.when(
          data: (user) => _buildProfileBody(context, user),
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
      },
    );
  }

  Widget _buildProfileBody(BuildContext context, UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // User profile card
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
                  backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                  child: Icon(
                    widget.userRole == UserRole.doctor ? Icons.medical_services : Icons.person,
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
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.userRole == UserRole.doctor ? 'Bác sĩ' : 'Bệnh nhân',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Profile information
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
                  'Thông tin cá nhân',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoTile(
                  icon: Icons.email,
                  title: 'Email',
                  subtitle: user?.email ?? 'Chưa cập nhật',
                ),
                const Divider(),
                _buildInfoTile(
                  icon: Icons.date_range,
                  title: 'Ngày tạo tài khoản',
                  subtitle: user?.createdAt.toString().split(' ')[0] ?? 'Chưa cập nhật',
                ),
                if (widget.userRole == UserRole.patient) ...[
                  const Divider(),
                  _buildInfoTile(
                    icon: Icons.medical_information,
                    title: 'Bệnh lý quan tâm',
                    subtitle: user?.diseaseFocus ?? 'Chưa cập nhật',
                  ),
                ],
                if (widget.userRole == UserRole.doctor) ...[
                  const Divider(),
                  _buildInfoTile(
                    icon: Icons.work,
                    title: 'Vai trò',
                    subtitle: widget.userRole == UserRole.doctor ? 'Bác sĩ' : 'Bệnh nhân',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Settings section
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
                  'Cài đặt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.primaryColor),
                  title: const Text('Chỉnh sửa thông tin'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to edit profile
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.security, color: AppColors.primaryColor),
                  title: const Text('Đổi mật khẩu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to change password
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.help, color: AppColors.primaryColor),
                  title: const Text('Trợ giúp'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to help
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Logout button
          SizedBox(
            width: double.infinity,
            child: Consumer(
              builder: (context, ref, child) {
                final authState = ref.watch(authProvider);
                
                return LogoutButton(
                  isLoading: authState.isLoading,
                  onPressed: () async {
                    try {
                      // Thực hiện logout thông qua AuthProvider
                      await ref.read(authProvider.notifier).logout();
                      
                      // Điều hướng về trang login
                      if (context.mounted) {
                        AppRouter.pushLogin(context);
                      }
                    } catch (e) {
                      // Hiển thị lỗi nếu có
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
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primaryColor),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}