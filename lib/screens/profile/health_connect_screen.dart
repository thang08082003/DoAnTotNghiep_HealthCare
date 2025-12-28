import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/profile/health_connect_viewmodel.dart';
import '../../data/services/passive_sync_service.dart';

class GoogleFitConnectScreen extends ConsumerStatefulWidget {
  const GoogleFitConnectScreen({super.key});

  @override
  ConsumerState<GoogleFitConnectScreen> createState() =>
      _GoogleFitConnectScreenState();
}

class _GoogleFitConnectScreenState
    extends ConsumerState<GoogleFitConnectScreen> {
  bool _loading = false;
  double? _latestHr;
  DateTime? _latestHrTime;
  double? _latestSpo2;
  DateTime? _latestSpo2Time;
  Duration? _todaySleep;
  String? _error;

  final PassiveSyncService _passiveSyncService = PassiveSyncService();

  Future<void> _togglePassiveSync(bool value) async {
    // Block for doctors
    final user = await ref.read(currentUserProvider.future);
    if (user != null && user.isDoctor && value) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bác sĩ không được bật Passive Sync')),
        );
      }
      return;
    }

    try {
      if (value) {
        await _passiveSyncService.enable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã bật đồng bộ thụ động (mỗi 15 phút)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _passiveSyncService.disable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tắt đồng bộ thụ động'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _connectAndFetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vm = ref.read(healthConnectViewModelProvider.notifier);
      final snap = await vm.fetchLatestMetrics();
      _latestHr = snap.hr;
      _latestHrTime = snap.hrTime;
      _latestSpo2 = snap.spo2;
      _latestSpo2Time = snap.spo2Time;
      _todaySleep = snap.todaySleep;

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã kết nối Health Connect và tải dữ liệu hiện tại'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết nối Health Connect'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kết nối Health Connect để đồng bộ dữ liệu Sức khỏe (Nhịp tim, SpO₂, Giấc ngủ).',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _connectAndFetch,
              icon: const Icon(Icons.favorite),
              label: Text(_loading ? 'Đang xử lý...' : 'Tải dữ liệu hiện tại'),
            ),
            const SizedBox(height: 24),

            // Sync Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_sync,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Đồng bộ dữ liệu lên Firebase',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lấy dữ liệu từ Health Connect, lưu vào SQLite, sau đó đẩy lên Firebase.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Passive Sync Toggle
                    FutureBuilder<bool>(
                      future: _passiveSyncService.isEnabled(),
                      builder: (context, snapshot) {
                        final isEnabled = snapshot.data ?? false;
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Đồng bộ thụ động',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            isEnabled
                                ? 'Tự động lấy dữ liệu từ Health Connect mỗi 15 phút và đẩy lên Firebase'
                                : 'Tắt - chỉ đồng bộ khi bạn nhấn nút đồng bộ ngay',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          value: isEnabled,
                          onChanged: _loading ? null : _togglePassiveSync,
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Sync Now Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading
                            ? null
                            : () async {
                                setState(() => _loading = true);

                                try {
                                  debugPrint('🔄 [UI] Bắt đầu đồng bộ ngay...');
                                  final result = await _passiveSyncService
                                      .syncNow();

                                  debugPrint('✅ [UI] Kết quả: $result');

                                  if (mounted) {
                                    if (result.success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Đã đồng bộ (24h gần nhất):\n'
                                            'HR: ${result.heartRateCount}, '
                                            'SpO2: ${result.spo2Count}, '
                                            'Sleep: ${result.sleepCount}\n'
                                            'Uploaded: ${result.uploadedToFirebase} records',
                                          ),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                      // Refresh data
                                      await _connectAndFetch();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Lỗi: ${result.message}'),
                                          backgroundColor: Colors.orange,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e, stack) {
                                  debugPrint('❌ [UI] Lỗi đồng bộ: $e');
                                  debugPrint('Stack: $stack');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Lỗi đồng bộ: $e'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _loading = false);
                                }
                              },
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Đồng bộ ngay (24h gần nhất)'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info banner
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
                              'Lưu ý: Chức năng này chỉ đồng bộ dữ liệu, không phân tích. Để phân tích sức khỏe, vào trang "Cảnh báo sức khỏe"',
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
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _dumpHealthLog(days: 7),
              icon: const Icon(Icons.bug_report),
              label: const Text('Xuất log dữ liệu (7 ngày)'),
            ),

            const SizedBox(height: 24),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            _metricRow(
              'Nhịp tim hiện tại',
              _formatCurrent(_latestHr, _latestHrTime, 'bpm'),
            ),
            const SizedBox(height: 8),
            _metricRow(
              'SpO₂ hiện tại',
              _formatCurrent(_latestSpo2, _latestSpo2Time, '%'),
            ),
            const SizedBox(height: 8),
            _metricRow(
              'Giấc ngủ (hôm nay)',
              _formatDuration(_todaySleep ?? Duration.zero),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes <= 0) return '—';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m}m';
  }

  String _formatCurrent(double? v, DateTime? t, String unit) {
    if (v == null || v <= 0) return '—';
    if (t == null) return '${v.toStringAsFixed(0)} $unit';
    final tod = TimeOfDay.fromDateTime(t);
    final hh = tod.hour.toString().padLeft(2, '0');
    final mm = tod.minute.toString().padLeft(2, '0');
    return '${v.toStringAsFixed(0)} $unit (lúc $hh:$mm)';
  }

  Future<void> _dumpHealthLog({int days = 7}) async {
    final vm = ref.read(healthConnectViewModelProvider.notifier);
    await vm.dumpHealthLog(days: days);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã in log dữ liệu ra console')),
    );
  }
}
