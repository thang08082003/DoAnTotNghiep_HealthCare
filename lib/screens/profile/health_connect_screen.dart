import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import '../../providers/user_provider.dart';
import '../../viewmodels/profile/health_connect_viewmodel.dart';

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
  bool _passiveEnabled = false;
  static const _prefsPassiveKey = 'passive_listener_enabled';
  static const _passiveChannel = MethodChannel(
    'com.example.healthcare/passive',
  );

  @override
  void initState() {
    super.initState();
    _loadPassiveToggle();
  }

  Future<void> _loadPassiveToggle() async {
    final prefs = await SharedPreferences.getInstance();
    final on = prefs.getBool(_prefsPassiveKey) ?? false;
    if (mounted) setState(() => _passiveEnabled = on);
  }

  Future<void> _setPassiveToggle(bool value) async {
    setState(() => _passiveEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsPassiveKey, value);
    // Call into native to register/unregister
    if (!Platform.isAndroid) return;
    try {
      if (value) {
        // Block for doctors
        final user = await ref.read(currentUserProvider.future);
        if (user != null && user.isDoctor) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bác sĩ không được bật Passive Sync'),
              ),
            );
          }
          setState(() => _passiveEnabled = false);
          await prefs.setBool(_prefsPassiveKey, false);
          return;
        }
        await _passiveChannel.invokeMethod('enablePassiveListener', {
          'role': user?.isDoctor == true ? 'doctor' : 'patient',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã bật đồng bộ thụ động (Passive)')),
          );
        }
      } else {
        await _passiveChannel.invokeMethod('disablePassiveListener');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tắt đồng bộ thụ động (Passive)')),
          );
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi Passive listener: ${e.message}')),
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
              label: Text(_loading ? 'Đang xử lý...' : 'Tải dữ liệu'),
            ),
            const SizedBox(height: 8),
            // Passive Listener toggle under settings, below connect button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Đồng bộ thụ động (Passive Listener)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _passiveEnabled,
                  onChanged: _loading
                      ? null
                      : (v) {
                          _setPassiveToggle(v);
                        },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Trigger immediate drain now (manual)
            ElevatedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      try {
                        await _passiveChannel.invokeMethod(
                          'enablePassiveListener',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã kích hoạt đồng bộ ngay'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi kích hoạt: $e')),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('Đồng bộ ngay (chạy 1 lần)'),
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
