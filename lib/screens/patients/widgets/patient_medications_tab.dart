import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/medication_prescription_model.dart';
import '../../../data/services/prescription_service.dart';
import '../../../components/medication/prescription_card.dart';
import '../../../providers/user_provider.dart';

class PatientMedicationsTab extends ConsumerWidget {
  final String patientId;
  final bool isPending;

  const PatientMedicationsTab({
    super.key,
    required this.patientId,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isPending) {
      return _buildPendingMessage();
    }

    final prescriptionService = ref.watch(prescriptionServiceProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        final isPatientView = currentUser?.isPatient ?? false;

        return StreamBuilder<List<MedicationPrescription>>(
          stream: prescriptionService.getPrescriptionsForPatient(patientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            }

            final prescriptions = snapshot.data ?? [];

            if (prescriptions.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text('Chưa có chỉ định thuốc nào'),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: prescriptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return PrescriptionCard(
                  prescription: prescriptions[index],
                  isPatientView: isPatientView,
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Lỗi: $error')),
    );
  }

  Widget _buildPendingMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.orange.shade300),
            const SizedBox(height: 16),
            const Text(
              'Thông tin này sẽ hiển thị sau khi bạn chấp nhận yêu cầu theo dõi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
