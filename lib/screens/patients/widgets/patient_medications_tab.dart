import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/medication_model.dart';
import '../../../data/services/medication_service.dart';

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

    final medicationService = ref.watch(medicationServiceProvider);

    return StreamBuilder<List<Medication>>(
      stream: medicationService.getMedications(patientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final medications = snapshot.data ?? [];
        if (medications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Bệnh nhân chưa có thuốc nào'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: medications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final medication = medications[index];
            return _MedicationCard(medication: medication);
          },
        );
      },
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

class _MedicationCard extends StatelessWidget {
  final Medication medication;

  const _MedicationCard({required this.medication});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: medication.isActive
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.medication,
                    color: medication.isActive ? Colors.orange : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (medication.dosage != null)
                        Text(
                          medication.dosage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!medication.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Đã ngưng',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
              ],
            ),
            if (medication.frequency != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    medication.frequency!,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (medication.instructions != null) ...[
              const SizedBox(height: 8),
              Text(
                medication.instructions!,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            if (medication.startDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Từ ${DateFormat('dd/MM/yyyy').format(medication.startDate!)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  if (medication.endDate != null)
                    Text(
                      ' đến ${DateFormat('dd/MM/yyyy').format(medication.endDate!)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
