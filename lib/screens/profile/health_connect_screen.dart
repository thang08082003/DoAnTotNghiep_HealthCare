import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/health_connect_service.dart';

class GoogleFitConnectScreen extends ConsumerStatefulWidget {
  const GoogleFitConnectScreen({super.key});

  @override
  ConsumerState<GoogleFitConnectScreen> createState() =>
      _GoogleFitConnectScreenState();
}

class _GoogleFitConnectScreenState
    extends ConsumerState<GoogleFitConnectScreen> {
  bool _loading = false;
  GoogleFitSummary? _summary;
  String? _error;

  Future<void> _connectAndFetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = GoogleFitService();
      // Fetch a broader window initially to ensure we pick up recent synced data
      final s = await svc.fetchSummary(range: const Duration(days: 30));
      if (!mounted) return;
      setState(() => _summary = s);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã kết nối Health Connect và tải dữ liệu'),
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
      appBar: AppBar(title: const Text('Kết nối Health Connect')),
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
              label: Text(
                _loading ? 'Đang xử lý...' : 'Kết nối và tải dữ liệu',
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_summary != null) ...[
              _metricRow(
                'Nhịp tim trung bình',
                _summary!.averageHeartRate != null
                    ? '${_summary!.averageHeartRate!.toStringAsFixed(1)} bpm'
                    : '—',
              ),
              const SizedBox(height: 8),
              _metricRow(
                'SpO₂ trung bình',
                _summary!.averageSpo2 != null
                    ? '${_summary!.averageSpo2!.toStringAsFixed(1)} %'
                    : '—',
              ),
              const SizedBox(height: 8),
              _metricRow(
                'Tổng thời gian ngủ (7 ngày)',
                _formatDuration(_summary!.totalSleep),
              ),
            ],
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
}
