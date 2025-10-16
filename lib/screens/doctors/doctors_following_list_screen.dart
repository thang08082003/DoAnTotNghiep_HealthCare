import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../data/services/follow_request_service.dart';
import '../../components/doctor/doctor_card.dart';
import 'doctor_detail_screen.dart';

class DoctorsFollowingListScreen extends ConsumerStatefulWidget {
  const DoctorsFollowingListScreen({super.key});

  @override
  ConsumerState<DoctorsFollowingListScreen> createState() =>
      _DoctorsFollowingListScreenState();
}

class _DoctorsFollowingListScreenState
    extends ConsumerState<DoctorsFollowingListScreen> {
  bool _loading = true;
  String? _error;
  List<DoctorModel> _doctors = const [];

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
      if (currentUser == null || !currentUser.isPatient) {
        setState(() {
          _loading = false;
          _doctors = const [];
        });
        return;
      }
      final doctorIds =
          await FollowRequestService.getAcceptedDoctorIdsForPatient(
            currentUser.uid,
          );
      if (doctorIds.isEmpty) {
        setState(() {
          _loading = false;
          _doctors = const [];
        });
        return;
      }
      final repo = ref.read(userRepositoryProvider);
      final futures = doctorIds.map((id) => repo.getUserById(id));
      final results = await Future.wait(futures);
      final doctors = results
          .whereType<UserModel>()
          .whereType<DoctorModel>()
          .cast<DoctorModel>()
          .toList();
      setState(() {
        _doctors = doctors;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi tải danh sách bác sĩ đang theo dõi: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bác sĩ đang theo dõi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : (_doctors.isEmpty)
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _doctors.length,
              itemBuilder: (context, index) {
                final d = _doctors[index];
                return Column(
                  children: [
                    DoctorCard(
                      doctor: d,
                      showBookButton: false,
                      primaryActionText: 'Trao đổi',
                      onPrimaryAction: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DoctorDetailScreen(
                              doctorId: d.uid,
                              initialTab: 1,
                            ),
                          ),
                        );
                      },
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DoctorDetailScreen(doctorId: d.uid),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.group_off, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Bạn chưa được bác sĩ nào chấp nhận theo dõi'),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Hãy gửi yêu cầu theo dõi đến bác sĩ phù hợp trong mục Bác sĩ.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
