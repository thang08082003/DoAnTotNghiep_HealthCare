import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/base_page/base_page_scaffold.dart';
import '../doctors/doctors_list_content.dart';
import '../../data/models/user_model.dart';
import '../../components/loading/loading_widget.dart';
import '../../components/buttons/primary_button.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../notifications/notifications_content.dart';
import '../dashboard/patient_dashboard_content.dart';
import '../dashboard/doctor_dashboard_content.dart';
import '../profile/profile_content.dart';

class HomePage extends BasePage {
  const HomePage({super.key, required UserRole userRole})
    : super(title: 'Trang chủ', userRole: userRole);

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
              ? const PatientDashboardContent()
              : const DoctorDashboardContent(),
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
    return const DoctorsListContent();
  }

  // Notifications content
  Widget _buildNotificationsContent() {
    return const NotificationsListContent();
  }

  // Notifications content extracted; helpers now live in notifications_content.dart

  // Profile content
  Widget _buildProfileContent() {
    return const ProfileContent();
  }

  // Dashboard/profile helper widgets were extracted to their content files.
}
