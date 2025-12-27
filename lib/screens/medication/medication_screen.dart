import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/medication_model.dart';
import '../../data/models/medication_prescription_model.dart';
import '../../data/services/medication_service.dart';
import '../../data/services/prescription_service.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/medication/medication_viewmodel.dart';
import '../../components/medication/medication_card.dart';
import '../../components/medication/prescription_card.dart';
import '../../components/medication/medication_details_dialog.dart';

/// Trang quản lý thuốc - View layer (MVVM)
class MedicationScreen extends ConsumerWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final viewModel = ref.watch(medicationViewModelProvider.notifier);
    final state = ref.watch(medicationViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thuốc của tôi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              state.showActiveOnly ? Icons.filter_list : Icons.filter_list_off,
            ),
            onPressed: () => viewModel.toggleShowActiveOnly(),
            tooltip: state.showActiveOnly ? 'Hiển thị tất cả' : 'Chỉ đang dùng',
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Vui lòng đăng nhập'));
          }

          final medicationService = ref.watch(medicationServiceProvider);
          final prescriptionService = ref.watch(prescriptionServiceProvider);
          
          return StreamBuilder<List<MedicationPrescription>>(
            stream: prescriptionService.getPrescriptionsForPatient(user.uid),
            builder: (context, prescriptionSnapshot) {
              return StreamBuilder<List<Medication>>(
                stream: state.showActiveOnly
                    ? medicationService.getActiveMedications(user.uid)
                    : medicationService.getMedications(user.uid),
                builder: (context, medicationSnapshot) {
                  if (prescriptionSnapshot.connectionState == ConnectionState.waiting ||
                      medicationSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (prescriptionSnapshot.hasError || medicationSnapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text('Lỗi: ${prescriptionSnapshot.error ?? medicationSnapshot.error}'),
                        ],
                      ),
                    );
                  }

                  final prescriptions = prescriptionSnapshot.data ?? [];
                  final medications = medicationSnapshot.data ?? [];

                  if (prescriptions.isEmpty && medications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medication_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có thuốc hoặc chỉ định nào',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Prescriptions section
                      if (prescriptions.isNotEmpty) ...[
                        const Text(
                          'Chỉ định thuốc từ bác sĩ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...prescriptions.map((prescription) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PrescriptionCard(
                              prescription: prescription,
                              isPatientView: true,
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                      // Medications section
                      if (medications.isNotEmpty) ...[
                        const Text(
                          'Thuốc đang dùng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final medication = medications[index];
                  return MedicationCard(
                    medication: medication,
                    onTap: () => _showMedicationDetails(context, medication),
                    enableDismiss: false,
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi: $error')),
      ),
    );
  }

  void _showMedicationDetails(BuildContext context, Medication medication) {
    showDialog(
      context: context,
      builder: (context) => MedicationDetailsDialog(medication: medication),
    );
  }
}
