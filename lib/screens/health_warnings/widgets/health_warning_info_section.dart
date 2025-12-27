import 'package:flutter/material.dart';
import '../../../data/resources/gene/app_colors.dart';

class HealthWarningInfoSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            'Về cảnh báo sức khỏe',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hệ thống sẽ tự động phân tích dữ liệu sức khỏe của bạn và đưa ra cảnh báo khi:\n\n'
            'Phát hiện chỉ số bất thường\n'
            'Có dấu hiệu cần theo dõi\n'
            'Cần tái khám hoặc kiểm tra sức khỏe\n'
            'Có khuyến nghị từ bác sĩ điều trị',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (lastSyncTime != null) ...[
            const SizedBox(height: 12),
            Text(
              'Lần đồng bộ gần nhất: ${_formatDateTime(lastSyncTime!)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
