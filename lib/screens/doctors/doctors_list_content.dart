import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/doctor/doctor_card.dart';
import '../../components/loading/loading_widget.dart';
import '../../data/models/doctor_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/follow_request_service.dart';
import '../../data/models/user_model.dart';
import '../../providers/user_provider.dart';

class DoctorsListContent extends ConsumerStatefulWidget {
  const DoctorsListContent({super.key});

  @override
  DoctorsListContentState createState() => DoctorsListContentState();
}

class DoctorsListContentState extends ConsumerState<DoctorsListContent> {
  List<DoctorModel> _doctors = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  Map<String, String> _requestStatuses = {}; // doctorId -> status

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userRepo = ref.read(userRepositoryProvider);
      final users = await userRepo.getUsersByRole(UserRole.doctor);
      final doctors = users.whereType<DoctorModel>().toList();

      try {
        final currentUser = await ref.read(currentUserProvider.future);
        if (currentUser != null && currentUser.isPatient) {
          _requestStatuses = await FollowRequestService.getRequestsForPatient(
            currentUser.uid,
          );
        } else {
          _requestStatuses = {};
        }
      } catch (_) {
        _requestStatuses = {};
      }

      if (mounted) {
        setState(() {
          _doctors = doctors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Có lỗi xảy ra khi tải danh sách bác sĩ: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm bác sĩ...',
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
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(child: _buildDoctorsList()),
      ],
    );
  }

  Widget _buildDoctorsList() {
    if (_isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDoctors,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final filteredDoctors = _doctors.where((doctor) {
      final matchesSearch = doctor.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return matchesSearch;
    }).toList();

    if (filteredDoctors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'Không tìm thấy bác sĩ nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredDoctors.length,
      itemBuilder: (context, index) {
        final doctor = filteredDoctors[index];
        final status = _requestStatuses[doctor.uid];
        final isPending = status == 'pending';
        final isAccepted = status == 'accepted';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DoctorCard(
            doctor: doctor,
            showBookButton: false,
            primaryActionText: isAccepted
                ? 'Đang theo dõi'
                : (isPending ? 'Đã gửi yêu cầu' : 'Request theo dõi'),
            primaryActionDisabled: isPending || isAccepted,
            onPrimaryAction: () async {
              final messenger = ScaffoldMessenger.of(context);
              final currentUser = await ref.read(currentUserProvider.future);
              if (currentUser == null || !currentUser.isPatient) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Bạn cần đăng nhập bằng tài khoản bệnh nhân.',
                    ),
                  ),
                );
                return;
              }
              try {
                final ok = await FollowRequestService.requestFollow(
                  patientId: currentUser.uid,
                  doctorId: doctor.uid,
                );
                if (ok) {
                  if (!mounted) return;
                  setState(() {
                    _requestStatuses[doctor.uid] = 'pending';
                  });
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Đã gửi yêu cầu theo dõi đến bác sĩ.'),
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gửi yêu cầu thất bại: $e')),
                );
              }
            },
          ),
        );
      },
    );
  }
}
