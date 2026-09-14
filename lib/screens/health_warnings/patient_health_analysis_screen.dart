import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/health_warnings/patient_health_analysis_viewmodel.dart';
import 'widgets/health_analysis_result_card.dart';

class PatientHealthAnalysisScreen extends ConsumerWidget {
  final UserModel patient;
  const PatientHealthAnalysisScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = patientHealthAnalysisViewModelProvider(patient.uid);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Cảnh báo - ${patient.name}'),
        centerTitle: true,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => notifier.load(patient.uid),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PatientHeader(patient: patient),
                  const SizedBox(height: 16),
                  if (state.error != null) _ErrorBanner(message: state.error!),
                  if (state.history.isEmpty)
                    const _EmptyHistory()
                  else
                    ...state.history.map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: HealthAnalysisResultCard(record: record),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  final UserModel patient;
  const _PatientHeader({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.12),
            backgroundImage:
                (patient.avatarUrl != null && patient.avatarUrl!.isNotEmpty)
                ? NetworkImage(patient.avatarUrl!)
                : null,
            child: (patient.avatarUrl == null || patient.avatarUrl!.isEmpty)
                ? const Icon(Icons.person, color: AppColors.primaryColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  patient.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (patient.phone != null && patient.phone!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      patient.phone!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.history_toggle_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 10),
            Text(
              'Chưa có kết quả phân tích',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Hãy nhắc bệnh nhân đồng bộ và phân tích dữ liệu sức khỏe.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
