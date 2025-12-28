import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthcare/data/services/passive_sync_service.dart';
import 'package:healthcare/providers/auto_analysis_provider.dart';

/// Provider cho trạng thái passive sync
final passiveSyncEnabledProvider =
    StateNotifierProvider<PassiveSyncNotifier, bool>((ref) {
      return PassiveSyncNotifier();
    });

class PassiveSyncNotifier extends StateNotifier<bool> {
  final PassiveSyncService _service = PassiveSyncService();

  PassiveSyncNotifier() : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    state = await _service.isEnabled();
  }

  Future<void> toggle() async {
    final newState = await _service.toggle();
    state = newState;
  }
}

/// Widget section cho Health Sync Settings
class HealthSyncSettingsSection extends ConsumerWidget {
  const HealthSyncSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passiveSyncEnabled = ref.watch(passiveSyncEnabledProvider);
    final autoAnalysisEnabled = ref.watch(autoAnalysisEnabledProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Đồng bộ và Phân tích',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Passive Sync Toggle
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: passiveSyncEnabled
                      ? Colors.green.shade50
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.cloud_sync,
                  color: passiveSyncEnabled ? Colors.green : Colors.grey,
                ),
              ),
              title: const Text(
                'Đồng bộ thụ động',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                passiveSyncEnabled
                    ? 'Tự động đồng bộ dữ liệu mỗi 15 phút'
                    : 'Tắt - chỉ đồng bộ khi bạn yêu cầu',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              trailing: Switch(
                value: passiveSyncEnabled,
                onChanged: (value) async {
                  try {
                    await ref
                        .read(passiveSyncEnabledProvider.notifier)
                        .toggle();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Đã bật đồng bộ thụ động'
                                : 'Đã tắt đồng bộ thụ động',
                          ),
                          backgroundColor: value ? Colors.green : Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),

            // Sync Now Button
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Show loading dialog
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Đang đồng bộ...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  try {
                    final service = PassiveSyncService();
                    final result = await service.syncNow();

                    if (context.mounted) {
                      Navigator.of(context).pop(); // Close loading dialog

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã đồng bộ: ${result.heartRateCount} HR, '
                            '${result.spo2Count} SpO2, '
                            '${result.sleepCount} Sleep\n'
                            'Uploaded: ${result.uploadedToFirebase} records',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context).pop(); // Close loading dialog

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi đồng bộ: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Đồng bộ ngay'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  side: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Auto Analysis Toggle
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: autoAnalysisEnabled
                      ? Colors.blue.shade50
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: autoAnalysisEnabled ? Colors.blue : Colors.grey,
                ),
              ),
              title: const Text(
                'Phân tích tự động',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                autoAnalysisEnabled
                    ? 'Tự động phân tích sức khỏe mỗi 30 phút'
                    : 'Tắt - chỉ phân tích khi bạn yêu cầu',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              trailing: Switch(
                value: autoAnalysisEnabled,
                onChanged: (value) async {
                  try {
                    await ref
                        .read(autoAnalysisEnabledProvider.notifier)
                        .toggleSwitch();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Đã bật phân tích tự động'
                                : 'Đã tắt phân tích tự động',
                          ),
                          backgroundColor: value ? Colors.green : Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),

            // Info banner
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dữ liệu được lưu vào SQLite trước, sau đó đồng bộ lên Firebase để tránh trùng lặp',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
