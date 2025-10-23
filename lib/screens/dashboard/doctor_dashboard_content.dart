import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../data/services/follow_request_service.dart';
import '../../data/models/user_model.dart';
import '../patients/patient_detail_screen.dart';

import '../../components/reviews/reviews_list.dart';
import '../../viewmodels/reviews/doctor_reviews_view_model.dart';
import '../doctors/doctor_reviews_screen.dart';
import '../resources/clinical_resources_screen.dart';

class DoctorDashboardContent extends ConsumerWidget {
  const DoctorDashboardContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (user) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(26),
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.waving_hand,
                        color: Colors.white,
                        size: 26,
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
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Chúc bạn có một ngày làm việc hiệu quả',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Hỗ trợ
              const Text(
                'Hỗ trợ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _ClinicalInfoEntryButton(),

              const SizedBox(height: 24),

              const Text(
                'Cảnh báo bất thường gần đây',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _AbnormalAlertsPreview(doctorId: user?.uid ?? ''),

              const SizedBox(height: 24),

              const Text(
                'Nhận xét gần đây',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _RecentReviewsPreview(
                doctorId: user?.uid ?? '',
                doctorName: user?.name ?? '',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentReviewsPreview extends ConsumerWidget {
  final String doctorId;
  final String doctorName;
  const _RecentReviewsPreview({
    required this.doctorId,
    required this.doctorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (doctorId.isEmpty) {
      return _shell(Container());
    }
    final vm = ref.read(doctorReviewsViewModelProvider);
    return _shell(
      Column(
        children: [
          ReviewsList(doctorId: doctorId, reviewsVm: vm, limit: 3),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DoctorReviewsScreen(
                      doctorId: doctorId,
                      doctorName: doctorName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.list),
              label: const Text('Xem tất cả nhận xét'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shell(Widget child) {
    return Container(
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
      child: child,
    );
  }
}

// replaced by InlineUserAvatar in shared components

class _FollowedPatientsList extends ConsumerStatefulWidget {
  final String doctorId;
  const _FollowedPatientsList({required this.doctorId});

  @override
  ConsumerState<_FollowedPatientsList> createState() =>
      _FollowedPatientsListState();
}

class _FollowedPatientsListState extends ConsumerState<_FollowedPatientsList> {
  bool _loading = true;
  List<UserModel> _patients = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.doctorId.isEmpty) {
      setState(() {
        _loading = false;
        _patients = [];
      });
      return;
    }
    try {
      final ids = await FollowRequestService.getAcceptedPatientIdsForDoctor(
        widget.doctorId,
      );
      final repo = ref.read(userRepositoryProvider);
      final all = await repo.getUsersByRole(UserRole.patient);
      final filtered = all.where((u) => ids.contains(u.uid)).toList();
      if (mounted) {
        setState(() {
          _patients = filtered;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lỗi tải danh sách: $_error',
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      );
    }
    if (_patients.isEmpty) {
      return const Text(
        'Chưa có bệnh nhân nào được chấp nhận theo dõi.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = _patients[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                backgroundImage:
                    (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                    ? NetworkImage(p.avatarUrl!)
                    : null,
                child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, color: AppColors.primaryColor)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.email,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PatientDetailScreen(patientId: p.uid),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AbnormalAlertsPreview extends StatelessWidget {
  final String doctorId;
  const _AbnormalAlertsPreview({required this.doctorId});

  @override
  Widget build(BuildContext context) {
    // Placeholder UI. In a next pass, we can query notifications for patients under this doctor
    // filtered by type ai_alert and recent time window.
    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chưa có cảnh báo nào trong 24h qua.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicalInfoEntryButton extends StatelessWidget {
  const _ClinicalInfoEntryButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ClinicalResourcesScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE8F0FE),
              child: Icon(Icons.menu_book, color: AppColors.primaryColor),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Thông tin chuyên môn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Truy cập hướng dẫn lâm sàng, phác đồ điều trị, tài liệu y khoa nội bộ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
