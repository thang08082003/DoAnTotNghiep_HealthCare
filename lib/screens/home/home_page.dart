import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/base_page/base_page_scaffold.dart';
import '../../data/models/user_model.dart';
import '../../components/loading/loading_widget.dart';
import '../../components/buttons/primary_button.dart';
import '../../components/buttons/logout_button.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';

class HomePage extends BasePage {
  const HomePage({super.key}) : super(title: 'Trang chủ', userRole: UserRole.patient);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends BasePageState<HomePage> {
  @override
  List<Widget> buildPages() {
    return [
      _buildDashboardContent(),
      _buildDoctorsContent(),
      _buildNotificationsContent(),
      _buildProfileContent(),
    ];
  }

  @override
  void onNavigationTap(int index) {
    // Let base class handle navigation
    setState(() {
      currentIndex = index;
    });
  }

  // Dashboard content
  Widget _buildDashboardContent() {
    return Consumer(
      builder: (context, ref, child) {
        final userAsyncValue = ref.watch(currentUserProvider);
        
        return userAsyncValue.when(
          data: (user) => user?.role == UserRole.patient 
              ? _buildPatientDashboard(user)
              : _buildDoctorDashboard(user),
          loading: () => const LoadingWidget(),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Lỗi: $error'),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Thử lại',
                  onPressed: () => ref.refresh(currentUserProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Doctors content
  Widget _buildDoctorsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_hospital, size: 64, color: AppColors.primaryColor),
          SizedBox(height: 16),
          Text(
            'Danh sách bác sĩ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tính năng đang được phát triển',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // Notifications content
  Widget _buildNotificationsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications, size: 64, color: AppColors.primaryColor),
          SizedBox(height: 16),
          Text(
            'Thông báo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Chưa có thông báo nào',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // Profile content
  Widget _buildProfileContent() {
    return Consumer(
      builder: (context, ref, child) {
        final userAsyncValue = ref.watch(currentUserProvider);
        
        return userAsyncValue.when(
          data: (user) => SingleChildScrollView(
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Settings section
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
      },
    );
  }

  // Helper methods for dashboard content
  Widget _buildPatientDashboard(dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor,
                  AppColors.primaryColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.waving_hand,
                        color: AppColors.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, ${user?.name ?? 'Bạn'}!',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Chúc bạn có một ngày tốt lành',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Statistics
          const Text(
            'Thống kê sức khỏe',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Lần khám', '0', Icons.medical_services),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Đơn thuốc', '0', Icons.medication),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorDashboard(dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor,
                  AppColors.primaryColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medical_services,
                        color: AppColors.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, Bs. ${user?.name ?? 'Bác sĩ'}!',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Hôm nay có nhiều bệnh nhân chờ khám',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Statistics
          const Text(
            'Thống kê hôm nay',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Bệnh nhân', '0', Icons.people),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Lịch hẹn', '0', Icons.schedule),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.primaryColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }


}