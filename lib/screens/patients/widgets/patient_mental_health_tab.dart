import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/anxiety_risk_model.dart';
import '../../../data/models/depression_risk_model.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../data/services/anxiety_risk_service.dart';
import '../../../data/services/depression_risk_service.dart';
import '../../../components/cards/mental_health_card.dart';

class PatientMentalHealthTab extends ConsumerWidget {
  final String patientId;
  final bool isPending;

  const PatientMentalHealthTab({
    super.key,
    required this.patientId,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isPending) {
      return _buildPendingMessage();
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppColors.primaryColor,
            tabs: [
              Tab(text: 'Nguy cơ lo âu'),
              Tab(text: 'Nguy cơ trầm cảm'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AnxietyListView(patientId: patientId),
                _DepressionListView(patientId: patientId),
              ],
            ),
          ),
        ],
      ),
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

class _AnxietyListView extends ConsumerWidget {
  final String patientId;

  const _AnxietyListView({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anxietyService = ref.watch(anxietyRiskServiceProvider);
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    return StreamBuilder<List<AnxietyRisk>>(
      stream: anxietyService.getAssessmentsByDateRange(
        userId: patientId,
        startDate: thirtyDaysAgo,
        endDate: now,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final assessments = snapshot.data ?? [];
        if (assessments.isEmpty) {
          return const Center(
            child: Text('Chưa có đánh giá nào trong 30 ngày qua'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: assessments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final assessment = assessments[index];
            return MentalHealthCard.anxiety(
              score: assessment.score,
              levelDescription: assessment.levelDescription,
              recommendation: assessment.recommendation,
              createdAt: assessment.createdAt,
            );
          },
        );
      },
    );
  }
}

class _DepressionListView extends ConsumerWidget {
  final String patientId;

  const _DepressionListView({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depressionService = ref.watch(depressionRiskServiceProvider);
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    return StreamBuilder<List<DepressionRisk>>(
      stream: depressionService.getAssessmentsByDateRange(
        userId: patientId,
        startDate: thirtyDaysAgo,
        endDate: now,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final assessments = snapshot.data ?? [];
        if (assessments.isEmpty) {
          return const Center(
            child: Text('Chưa có đánh giá nào trong 30 ngày qua'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: assessments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final assessment = assessments[index];
            return MentalHealthCard.depression(
              score: assessment.score,
              levelDescription: assessment.levelDescription,
              recommendation: assessment.recommendation,
              createdAt: assessment.createdAt,
            );
          },
        );
      },
    );
  }
}
