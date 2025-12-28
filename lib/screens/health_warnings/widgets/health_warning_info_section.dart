import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/resources/gene/app_colors.dart';
import '../../../providers/auto_analysis_provider.dart';

class HealthWarningInfoSection extends ConsumerWidget {
  final DateTime? lastSyncTime;
  final bool isSyncing;
  final VoidCallback onAnalyze;

  const HealthWarningInfoSection({
    super.key,
    this.lastSyncTime,
    required this.isSyncing,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoAnalysisEnabled = ref.watch(autoAnalysisEnabledProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Về phân tích và cảnh báo sức khỏe',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hệ thống sẽ phân tích dữ liệu đã đồng bộ trên Firebase và đưa ra cảnh báo khi phát hiện chỉ số bất thường.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Auto-analysis switch
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.autorenew,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phân tích tự động',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Phân tích dữ liệu mỗi 30 phút (chỉ phân tích, không đồng bộ)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: autoAnalysisEnabled,
                  onChanged: (value) async {
                    try {
                      await ref
                          .read(autoAnalysisEnabledProvider.notifier)
                          .toggle(value);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Đã bật phân tích tự động'
                                  : 'Đã tắt phân tích tự động',
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      // Revert state on error
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Lỗi: Không thể ${value ? "bật" : "tắt"} phân tích tự động',
                            ),
                            duration: const Duration(seconds: 3),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  activeColor: AppColors.primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSyncing ? null : onAnalyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSyncing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Phân tích ngay',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
