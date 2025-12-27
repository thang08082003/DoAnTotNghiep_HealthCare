import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../components/resources/resource_tile.dart';
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
        centerTitle: true,
        backgroundColor: AppColors.primaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ResourceTile(
            icon: Icons.menu_book,
            title: 'Hướng dẫn lâm sàng',
            subtitle: 'Các guideline cập nhật theo chuyên khoa',
            onTap: () => openUrl('https://www.who.int/'),
          ),
          const SizedBox(height: 8),
          ResourceTile(
            icon: Icons.medical_information,
            title: 'Phác đồ điều trị',
            subtitle: 'Phác đồ nội bộ và tham khảo quốc tế',
            onTap: () => openUrl('https://www.msdmanuals.com/professional'),
          ),
          const SizedBox(height: 8),
          ResourceTile(
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
