import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/health_warnings/health_analysis_viewmodel.dart';
import 'widgets/health_analysis_result_card.dart';
import 'widgets/health_warning_info_section.dart';

class HealthWarningsScreen extends ConsumerStatefulWidget {
  const HealthWarningsScreen({super.key});

  @override
  ConsumerState<HealthWarningsScreen> createState() =>
      _HealthWarningsScreenState();
}

class _HealthWarningsScreenState extends ConsumerState<HealthWarningsScreen> {
  @override
  void initState() {
    super.initState();
    // Load existing data when screen opens
    Future.microtask(() {
      ref.read(healthAnalysisViewModelProvider.notifier).loadExistingData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(healthAnalysisViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh báo sức khỏe'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: state.isLoading && !state.hasData
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.error != null) _buildErrorCard(state.error!),
                HealthWarningInfoSection(
                  lastSyncTime: state.lastSyncTime,
                  isSyncing: state.isSyncing,
                  onAnalyze: () => _handleAnalyze(context),
                ),
                const SizedBox(height: 16),
                if (state.analysisHistory.isNotEmpty) ...[
                  const Text(
                    'Lịch sử phân tích',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...state.analysisHistory.asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final record = entry.value;
                      return Dismissible(
                        key: Key('analysis_${record.timestamp.millisecondsSinceEpoch}_$index'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          ref.read(healthAnalysisViewModelProvider.notifier)
                              .deleteRecord(index);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã xóa kết quả phân tích'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        child: HealthAnalysisResultCard(record: record),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _handleAnalyze(BuildContext context) async {
    try {
      await ref.read(healthAnalysisViewModelProvider.notifier).syncAndAnalyze();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã phân tích dữ liệu thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lỗi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

enum WarningSeverity { critical, warning, info }
