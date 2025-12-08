import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/depression_risk_model.dart';
import '../../data/services/depression_risk_service.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/depression_risk/depression_risk_state.dart';
import '../../viewmodels/depression_risk/depression_risk_viewmodel.dart';
import '../../components/chart/phq9_chart_widget.dart';
import 'phq9_assessment_dialog.dart';

/// Màn hình đánh giá nguy cơ trầm cảm - View layer (MVVM)
class DepressionRiskScreen extends ConsumerWidget {
  const DepressionRiskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final viewModel = ref.watch(depressionRiskViewModelProvider.notifier);
    final state = ref.watch(depressionRiskViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nguy cơ trầm cảm'), centerTitle: true),
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
    DepressionRiskState state,
    DepressionRiskViewModel viewModel,
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
    DepressionRiskState state,
    DepressionRiskViewModel viewModel,
  ) {
    final service = ref.watch(depressionRiskServiceProvider);
    final dateRange = viewModel.getDateRange(state.timeRange);

    // Use key to force rebuild when timeRange changes
    return StreamBuilder<List<DepressionRisk>>(
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Lỗi: ${snapshot.error}'),
              ],
            ),
          );
        }

        final assessments = snapshot.data ?? [];

        if (assessments.isEmpty) {
          return _buildEmptyState(context);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Biểu đồ
              PHQ9ChartWidget(
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có đánh giá nào',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn nút bên dưới để thêm đánh giá mới',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentList(
    BuildContext context,
    List<DepressionRisk> assessments,
    DepressionRiskViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.list, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Danh sách đánh giá',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${assessments.length} đánh giá',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...assessments.map((assessment) {
          return _buildAssessmentCard(context, assessment, viewModel);
        }),
      ],
    );
  }

  Widget _buildAssessmentCard(
    BuildContext context,
    DepressionRisk assessment,
    DepressionRiskViewModel viewModel,
  ) {
    final color = _getLevelColor(assessment.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAssessmentDetails(context, assessment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${assessment.score}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assessment.levelDescription,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(assessment.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'minimal':
        return Colors.green;
      case 'mild':
        return Colors.lightGreen;
      case 'moderate':
        return Colors.orange;
      case 'moderately_severe':
        return Colors.deepOrange;
      case 'severe':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showAssessmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PHQ9AssessmentDialog(),
    );
  }

  void _showAssessmentDetails(BuildContext context, DepressionRisk assessment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(assessment.levelDescription),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Điểm: ${assessment.score}/27'),
            const SizedBox(height: 8),
            Text(
              'Ngày đánh giá: ${DateFormat('dd/MM/yyyy HH:mm').format(assessment.createdAt)}',
            ),
            if (assessment.note != null && assessment.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ghi chú: ${assessment.note}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
