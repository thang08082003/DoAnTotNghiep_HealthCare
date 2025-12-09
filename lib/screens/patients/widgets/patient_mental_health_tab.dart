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
    IconData levelIcon;

    if (assessment.score <= 4) {
      levelColor = Colors.green;
      levelIcon = Icons.sentiment_satisfied;
    } else if (assessment.score <= 9) {
      levelColor = Colors.orange;
      levelIcon = Icons.sentiment_neutral;
    } else if (assessment.score <= 14) {
      levelColor = Colors.deepOrange;
      levelIcon = Icons.sentiment_dissatisfied;
    } else {
      levelColor = Colors.red;
      levelIcon = Icons.sentiment_very_dissatisfied;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: levelColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(levelIcon, color: levelColor, size: 24),
        ),
        title: Row(
          children: [
            Text(
              '${assessment.score}/21 điểm',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: levelColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                assessment.levelDescription,
                style: TextStyle(
                  color: levelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          DateFormat('dd/MM/yyyy HH:mm').format(assessment.createdAt),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assessment.recommendation,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    IconData levelIcon;

    if (assessment.score <= 4) {
      levelColor = Colors.green;
      levelIcon = Icons.sentiment_satisfied;
    } else if (assessment.score <= 9) {
      levelColor = Colors.orange;
      levelIcon = Icons.sentiment_neutral;
    } else if (assessment.score <= 14) {
      levelColor = Colors.deepOrange;
      levelIcon = Icons.sentiment_dissatisfied;
    } else if (assessment.score <= 19) {
      levelColor = Colors.red;
      levelIcon = Icons.sentiment_very_dissatisfied;
    } else {
      levelColor = Colors.red.shade900;
      levelIcon = Icons.sentiment_very_dissatisfied;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: levelColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(levelIcon, color: levelColor, size: 24),
        ),
        title: Row(
          children: [
            Text(
              '${assessment.score}/27 điểm',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: levelColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                assessment.levelDescription,
                style: TextStyle(
                  color: levelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          DateFormat('dd/MM/yyyy HH:mm').format(assessment.createdAt),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assessment.recommendation,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
