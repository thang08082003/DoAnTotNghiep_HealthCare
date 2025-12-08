import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/anxiety_risk_model.dart';
import '../../../data/models/depression_risk_model.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../data/services/anxiety_risk_service.dart';
import '../../../data/services/depression_risk_service.dart';

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
            return _AnxietyCard(assessment: assessment);
          },
        );
      },
    );
  }
}

class _AnxietyCard extends StatelessWidget {
  final AnxietyRisk assessment;

  const _AnxietyCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    Color levelColor;
    if (assessment.score <= 4) {
      levelColor = Colors.green;
    } else if (assessment.score <= 9) {
      levelColor = Colors.orange;
    } else if (assessment.score <= 14) {
      levelColor = Colors.deepOrange;
    } else {
      levelColor = Colors.red;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: levelColor),
                  ),
                  child: Text(
                    '${assessment.score}/21',
                    style: TextStyle(
                      color: levelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  assessment.levelDescription,
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(assessment.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              assessment.recommendation,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
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
            return _DepressionCard(assessment: assessment);
          },
        );
      },
    );
  }
}

class _DepressionCard extends StatelessWidget {
  final DepressionRisk assessment;

  const _DepressionCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    Color levelColor;
    if (assessment.score <= 4) {
      levelColor = Colors.green;
    } else if (assessment.score <= 9) {
      levelColor = Colors.orange;
    } else if (assessment.score <= 14) {
      levelColor = Colors.deepOrange;
    } else if (assessment.score <= 19) {
      levelColor = Colors.red;
    } else {
      levelColor = Colors.red.shade900;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: levelColor),
                  ),
                  child: Text(
                    '${assessment.score}/27',
                    style: TextStyle(
                      color: levelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  assessment.levelDescription,
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(assessment.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              assessment.recommendation,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
