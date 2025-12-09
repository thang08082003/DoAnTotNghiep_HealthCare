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
    final icon = _getLevelIcon(assessment.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                assessment.levelDescription,
                style: TextStyle(
                  color: color,
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

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'minimal':
        return Icons.sentiment_satisfied;
      case 'mild':
        return Icons.sentiment_neutral;
      case 'moderate':
        return Icons.sentiment_dissatisfied;
      case 'moderately_severe':
        return Icons.sentiment_very_dissatisfied;
      case 'severe':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.help_outline;
    }
  }

  void _showAssessmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PHQ9AssessmentDialog(),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DepressionRisk assessment,
    DepressionRiskViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa đánh giá ngày ${DateFormat('dd/MM/yyyy HH:mm').format(assessment.createdAt)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
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
