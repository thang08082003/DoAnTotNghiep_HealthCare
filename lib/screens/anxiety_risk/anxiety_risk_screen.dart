import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/anxiety_risk_model.dart';
import '../../data/services/anxiety_risk_service.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/anxiety_risk/anxiety_risk_state.dart';
import '../../viewmodels/anxiety_risk/anxiety_risk_viewmodel.dart';
import '../../components/chart/gad7_chart_widget.dart';
import '../../components/dialog/custom_dialog.dart';
import 'gad7_assessment_dialog.dart';

/// Màn hình đánh giá nguy cơ lo âu - View layer (MVVM)
class AnxietyRiskScreen extends ConsumerWidget {
  const AnxietyRiskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final viewModel = ref.watch(anxietyRiskViewModelProvider.notifier);
    final state = ref.watch(anxietyRiskViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nguy cơ lo âu'), centerTitle: true),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Vui lòng đăng nhập'));
          }

          return Column(
            children: [
              // Segmented Control
              _buildSegmentedControl(context, ref, state, viewModel),

              // Content với chart và list
              Expanded(
                child: _buildContent(context, ref, user.uid, state, viewModel),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Lỗi: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssessmentDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Đánh giá mới'),
      ),
    );
  }

  Widget _buildSegmentedControl(
    BuildContext context,
    WidgetRef ref,
    AnxietyRiskState state,
    AnxietyRiskViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = (constraints.maxWidth / 3).clamp(
            0.0,
            double.infinity,
          );
          return SizedBox(
            width: constraints.maxWidth,
            child: CupertinoSegmentedControl<TimeRange>(
              padding: EdgeInsets.zero,
              groupValue: state.timeRange,
              children: {
                TimeRange.day: SizedBox(
                  width: segWidth,
                  child: const Center(child: Text('Ngày')),
                ),
                TimeRange.week: SizedBox(
                  width: segWidth,
                  child: const Center(child: Text('Tuần')),
                ),
                TimeRange.month: SizedBox(
                  width: segWidth,
                  child: const Center(child: Text('Tháng')),
                ),
              },
              onValueChanged: (TimeRange newValue) {
                viewModel.setTimeRange(newValue);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    String userId,
    AnxietyRiskState state,
    AnxietyRiskViewModel viewModel,
  ) {
    final service = ref.watch(anxietyRiskServiceProvider);
    final dateRange = viewModel.getDateRange(state.timeRange);

    // Use key to force rebuild when timeRange changes
    return StreamBuilder<List<AnxietyRisk>>(
      key: ValueKey(state.timeRange),
      stream: service.getAssessmentsByDateRange(
        userId: userId,
        startDate: dateRange.start,
        endDate: dateRange.end,
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
          return _buildEmptyState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Biểu đồ
              GAD7ChartWidget(
                assessments: assessments,
                timeRange: state.timeRange,
              ),
              const SizedBox(height: 24),

              // Danh sách đánh giá
              _buildAssessmentList(context, assessments, viewModel),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssessmentList(
    BuildContext context,
    List<AnxietyRisk> assessments,
    AnxietyRiskViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.list, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Lịch sử đánh giá',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${assessments.length} đánh giá',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...assessments.map(
          (assessment) => _buildAssessmentCard(context, assessment, viewModel),
        ),
      ],
    );
  }

  Widget _buildAssessmentCard(
    BuildContext context,
    AnxietyRisk assessment,
    AnxietyRiskViewModel viewModel,
  ) {
    Color levelColor;
    IconData levelIcon;

    switch (assessment.level) {
      case 'minimal':
        levelColor = Colors.green;
        levelIcon = Icons.sentiment_satisfied;
        break;
      case 'mild':
        levelColor = Colors.orange;
        levelIcon = Icons.sentiment_neutral;
        break;
      case 'moderate':
        levelColor = Colors.orange.shade700;
        levelIcon = Icons.sentiment_dissatisfied;
        break;
      case 'severe':
        levelColor = Colors.red;
        levelIcon = Icons.sentiment_very_dissatisfied;
        break;
      default:
        levelColor = Colors.grey;
        levelIcon = Icons.help_outline;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lời khuyên
                Container(
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
                const SizedBox(height: 12),

                // Nút xóa
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Xóa'),
                    onPressed: () =>
                        _confirmDelete(context, assessment, viewModel),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_neutral, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có đánh giá nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn nút "Đánh giá mới" để bắt đầu',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssessmentDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const GAD7AssessmentDialog(),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AnxietyRisk assessment,
    AnxietyRiskViewModel viewModel,
  ) async {
    final confirmed = await CustomDialog.showConfirmation(
      context: context,
      title: 'Xác nhận xóa',
      message:
          'Bạn có chắc muốn xóa đánh giá ngày ${DateFormat('dd/MM/yyyy HH:mm').format(assessment.createdAt)}?',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
    );

    if (confirmed == true && context.mounted) {
      await viewModel.deleteAssessment(assessment.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa đánh giá'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
