import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/follow_request_service.dart';
import '../../providers/user_provider.dart';
import 'patient_detail_screen.dart';

class PatientsListContent extends ConsumerStatefulWidget {
  const PatientsListContent({super.key});

  @override
  PatientsListContentState createState() => PatientsListContentState();
}

class PatientsListContentState extends ConsumerState<PatientsListContent> {
  bool _loading = false;
  String? _error;
  List<UserModel> _patients = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null || !currentUser.isDoctor) {
        setState(() {
          _patients = [];
          _loading = false;
          _error = 'Vui lòng đăng nhập bằng tài khoản bác sĩ';
        });
        return;
      }
      final ids = await FollowRequestService.getAcceptedPatientIdsForDoctor(
        currentUser.uid,
      );
      final repo = ref.read(userRepositoryProvider);
      final futures = ids.map((id) => repo.getUserById(id)).toList();
      final users = await Future.wait(futures);
      setState(() {
        _patients = users.whereType<UserModel>().toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Lỗi tải danh sách bệnh nhân: $e';
      });
    }
  }

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
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
            ),
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: LoadingWidget());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    final list = _patients.where(
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
              child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
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
