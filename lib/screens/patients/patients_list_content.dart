import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../components/patient/patient_card.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/patients/patients_following_view_model.dart';
import '../../data/services/follow_request_service.dart';
import '../../data/models/follow_request.dart';
import 'patient_detail_screen.dart';

class PatientsListContent extends ConsumerStatefulWidget {
  const PatientsListContent({super.key});

  @override
  PatientsListContentState createState() => PatientsListContentState();
}

class PatientsListContentState extends ConsumerState<PatientsListContent>
    with SingleTickerProviderStateMixin {
  String _search = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUser = currentUserAsync.value;

    if (currentUserAsync.isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (currentUser == null || !currentUser.isDoctor) {
      return const Center(
        child: Text('Vui lòng đăng nhập bằng tài khoản bác sĩ'),
      );
    }

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm bệnh nhân...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryColor),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref
                      .read(
                        patientsFollowingViewModelProvider(
                          currentUser.uid,
                        ).notifier,
                      )
                      .loadPatientsForDoctor(currentUser.uid);
                  setState(() {}); // Refresh pending list
                },
              ),
            ),
          ),
        ),
        // Tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryColor,
            tabs: const [
              Tab(text: 'Đang theo dõi'),
              Tab(text: 'Đang chờ'),
            ],
          ),
        ),
        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFollowingTab(currentUser.uid),
              _buildPendingTab(currentUser.uid),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowingTab(String doctorId) {
    final state = ref.watch(patientsFollowingViewModelProvider(doctorId));

    if (state.loading) return const Center(child: LoadingWidget());

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: AppColors.error),
            const SizedBox(height: 12),
            Text(state.error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(patientsFollowingViewModelProvider(doctorId).notifier)
                    .loadPatientsForDoctor(doctorId);
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final list = state.patients.where(
      (p) => p.name.toLowerCase().contains(_search.toLowerCase()),
    );
    final patients = list.toList();
    if (patients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'Chưa có bệnh nhân nào đang theo dõi',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = patients[i];
        return PatientCard(
          patient: p,
          statusText: 'Đang theo dõi',
          statusColor: AppColors.primaryColor,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientDetailScreen(patientId: p.uid),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingTab(String doctorId) {
    return StreamBuilder<List<FollowRequest>>(
      stream: FollowRequestService.watchPendingRequestsForDoctor(doctorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: LoadingWidget());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Lỗi: ${snapshot.error}'),
              ],
            ),
          );
        }

        final allRequests = snapshot.data ?? const <FollowRequest>[];
        final requests = allRequests
            .where(
              (r) =>
                  r.patientName.toLowerCase().contains(_search.toLowerCase()),
            )
            .toList();

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pending_actions,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 12),
                Text(
                  'Không có yêu cầu nào đang chờ',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = requests[i];
            // Create a temporary UserModel from FollowRequest data
            final tempPatient = UserModel(
              uid: r.patientId,
              name: r.patientName,
              email: r.patientEmail ?? '',
              role: UserRole.patient,
              avatarUrl: r.patientAvatarUrl,
              createdAt: r.createdAt ?? DateTime.now(),
            );

            return PatientCard(
              patient: tempPatient,
              statusText: 'Đang chờ xác nhận',
              statusColor: Colors.orange,
              isPending: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PatientDetailScreen(
                      patientId: r.patientId,
                      isPending: true, // Flag để ẩn health info
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
