import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/resources/gene/app_colors.dart';

class ClinicalResourcesScreen extends StatelessWidget {
  const ClinicalResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> openUrl(String url) async {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không thể mở liên kết')));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin chuyên môn'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ResourceTile(
            icon: Icons.menu_book,
            title: 'Hướng dẫn lâm sàng',
            subtitle: 'Các guideline cập nhật theo chuyên khoa',
            onTap: () => openUrl('https://www.who.int/'),
          ),
          const SizedBox(height: 8),
          _ResourceTile(
            icon: Icons.medical_information,
            title: 'Phác đồ điều trị',
            subtitle: 'Phác đồ nội bộ và tham khảo quốc tế',
            onTap: () => openUrl('https://www.msdmanuals.com/professional'),
          ),
          const SizedBox(height: 8),
          _ResourceTile(
            icon: Icons.folder_shared,
            title: 'Tài liệu y khoa nội bộ',
            subtitle: 'Quy trình, biểu mẫu, tài liệu đào tạo',
            onTap: () => openUrl('https://www.ncbi.nlm.nih.gov/pmc/'),
          ),
        ],
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ResourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE8F0FE),
              child: Icon(icon, color: AppColors.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
