import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/patients/patients_following_view_model.dart';
import 'patient_detail_screen.dart';

class PatientsListContent extends ConsumerStatefulWidget {
  const PatientsListContent({super.key});

  @override
  PatientsListContentState createState() => PatientsListContentState();
}

class PatientsListContentState extends ConsumerState<PatientsListContent> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                borderSide: BorderSide(color: AppColors.primaryColor),
              ),
              suffixIcon: Consumer(
                builder: (context, ref, _) {
                  final currentUser = ref.watch(currentUserProvider).value;
                  return IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: currentUser == null || !currentUser.isDoctor
                        ? null
                        : () {
                            ref
                                .read(
                                  patientsFollowingViewModelProvider(
                                    currentUser.uid,
                                  ).notifier,
                                )
                                .loadPatientsForDoctor(currentUser.uid);
                          },
                  );
                },
              ),
            ),
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    final currentUserAsync = ref.watch(currentUserProvider);
    if (currentUserAsync.isLoading) {
      return const Center(child: LoadingWidget());
    }
    final currentUser = currentUserAsync.value;
    if (currentUser == null || !currentUser.isDoctor) {
      return const Center(
        child: Text('Vui lòng đăng nhập bằng tài khoản bác sĩ'),
      );
    }
    final state = ref.watch(
      patientsFollowingViewModelProvider(currentUser.uid),
    );
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
                    .read(
                      patientsFollowingViewModelProvider(
                        currentUser.uid,
                      ).notifier,
                    )
                    .loadPatientsForDoctor(currentUser.uid);
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
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
              backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                  ? NetworkImage(p.avatarUrl!)
                  : null,
              child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                  ? Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primaryColor),
                    )
                  : null,
            ),
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              p.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PatientDetailScreen(patientId: p.uid),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              label: const Text('Xem'),
            ),
          ),
        );
      },
    );
  }
}
