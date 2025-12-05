import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';

import '../../components/doctor/doctor_card.dart';
import 'doctor_detail_screen.dart';
import 'book_appointment_screen.dart';
import '../../viewmodels/doctors/doctors_following_view_model.dart';

class DoctorsFollowingListScreen extends ConsumerStatefulWidget {
  const DoctorsFollowingListScreen({super.key});

  @override
  ConsumerState<DoctorsFollowingListScreen> createState() =>
      _DoctorsFollowingListScreenState();
}

class _DoctorsFollowingListScreenState
    extends ConsumerState<DoctorsFollowingListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bác sĩ đang theo dõi'),
        centerTitle: true,
      ),
      body: Consumer(
        builder: (context, ref, _) {
          return FutureBuilder(
            future: ref.read(currentUserProvider.future),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final currentUser = snap.data!;
              if (!currentUser.isPatient) return const _EmptyState();
              final state = ref.watch(
                doctorsFollowingViewModelProvider(currentUser.uid),
              );
              if (state.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(state.error!),
                    ],
                  ),
                );
              }
              final doctors = state.doctors;
              if (doctors.isEmpty) return const _EmptyState();
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final d = doctors[index];
                  return Column(
                    children: [
                      DoctorCard(
                        doctor: d,
                        showBookButton: true,
                        onBookAppointment: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BookAppointmentScreen(
                                doctorId: d.uid,
                                doctorName: d.name,
                              ),
                            ),
                          );
                        },
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
                              builder: (_) =>
                                  DoctorDetailScreen(doctorId: d.uid),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
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
