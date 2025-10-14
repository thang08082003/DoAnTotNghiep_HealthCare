import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/health_connect_service.dart';
import 'package:health/health.dart';
import '../../providers/health_metrics_providers.dart';
import '../../providers/user_provider.dart';

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
  Duration? _lastNightSleep;
  String? _error;

  Future<void> _connectAndFetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = GoogleFitService();
      // Ensure permissions
      await svc.ensureConnected();

      final now = DateTime.now();
      final dayAgo = now.subtract(const Duration(days: 1));

      // Latest Heart Rate in last 24h
      try {
        final hr = await svc.getData(
          types: [HealthDataType.HEART_RATE],
          start: dayAgo,
          end: now,
        );
        if (hr.isNotEmpty) {
          hr.sort((a, b) {
            final aa = a.dateTo.isAfter(a.dateFrom) ? a.dateTo : a.dateFrom;
            final bb = b.dateTo.isAfter(b.dateFrom) ? b.dateTo : b.dateFrom;
            return aa.compareTo(bb);
          });
          for (final p in hr.reversed) {
            final v = p.value;
            if (v is NumericHealthValue) {
              final bpm = v.numericValue.toDouble();
              if (bpm > 0) {
                _latestHr = bpm;
                _latestHrTime = p.dateTo.isAfter(p.dateFrom)
                    ? p.dateTo
                    : p.dateFrom;
                break;
              }
            }
          }
        }
      } catch (_) {}

      // Latest SpO2 in last 24h
      try {
        final spo2 = await svc.getData(
          types: [HealthDataType.BLOOD_OXYGEN],
          start: dayAgo,
          end: now,
        );
        if (spo2.isNotEmpty) {
          spo2.sort((a, b) {
            final aa = a.dateTo.isAfter(a.dateFrom) ? a.dateTo : a.dateFrom;
            final bb = b.dateTo.isAfter(b.dateFrom) ? b.dateTo : b.dateFrom;
            return aa.compareTo(bb);
          });
          for (final p in spo2.reversed) {
            final v = p.value;
            if (v is NumericHealthValue) {
              final pct = v.numericValue.toDouble();
              if (pct > 0) {
                _latestSpo2 = pct;
                _latestSpo2Time = p.dateTo.isAfter(p.dateFrom)
                    ? p.dateTo
                    : p.dateFrom;
                break;
              }
            }
          }
        }
      } catch (_) {}

      // Last night sleep duration
      try {
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        Duration total = Duration.zero;
        var sleep = await svc.getData(
          types: [HealthDataType.SLEEP_SESSION],
          start: yesterday,
          end: today,
        );
        if (sleep.isEmpty) {
          sleep = await svc.getData(
            types: [HealthDataType.SLEEP_ASLEEP],
            start: yesterday,
            end: today,
          );
        }
        for (final s in sleep) {
          final dt = s.dateTo.difference(s.dateFrom);
          if (!dt.isNegative) total += dt;
        }
        if (total > Duration.zero) {
          _lastNightSleep = total;
        }
      } catch (_) {}

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
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          try {
                            final user = await ref.read(
                              currentUserProvider.future,
                            );
                            if (user == null) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Chưa đăng nhập'),
                                  ),
                                );
                              }
                              return;
                            }
                            final repo = ref.read(
                              healthMetricsRepositoryProvider,
                            );
                            final res = await repo.syncLast24h(user.uid);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res.granted
                                        ? 'Đã đồng bộ 24h: HR ${res.heartRate}, SpO₂ ${res.spo2}, HRV ${res.hrv}, Ngủ ${res.sleep}'
                                        : 'Chưa cấp quyền Health Connect',
                                  ),
                                ),
                              );
                            }
                            // invalidate providers so any dashboard rebuild after pop sees new data
                            ref.invalidate(heartRateStreamProvider(user.uid));
                            ref.invalidate(spo2StreamProvider(user.uid));
                            ref.invalidate(hrvStreamProvider(user.uid));
                            ref.invalidate(
                              sleepSessionsStreamProvider(user.uid),
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Lỗi đồng bộ: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  icon: const Icon(Icons.sync),
                  label: Text(
                    _loading
                        ? 'Đang đồng bộ...'
                        : 'Đồng bộ 24h lên hệ thống (Firestore)',
                  ),
                );
              },
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
              'Giấc ngủ (đêm qua)',
              _formatDuration(_lastNightSleep ?? Duration.zero),
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
    final svc = GoogleFitService();
    try {
      await svc.ensureConnected();
    } catch (_) {}
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    // Header
    // ignore: avoid_print
    print(
      '===== Health Connect dump ${start.toIso8601String()} -> ${now.toIso8601String()} =====',
    );
    final types = <HealthDataType>[
      HealthDataType.HEART_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
    ];
    for (final t in types) {
      try {
        final data = await svc.getData(types: [t], start: start, end: now);
        data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        // Summary
        // ignore: avoid_print
        print('-- ${t.name}: count=${data.length}');
        if (data.isEmpty) continue;
        final first = data.first.dateFrom.toIso8601String();
        final last =
            (data.last.dateTo.isAfter(data.last.dateFrom)
                    ? data.last.dateTo
                    : data.last.dateFrom)
                .toIso8601String();
        // ignore: avoid_print
        print('   range: first=$first last=$last');
        for (final p in data) {
          final from = p.dateFrom.toIso8601String();
          final to = p.dateTo.toIso8601String();
          final v = p.value;
          String valStr;
          if (v is NumericHealthValue) {
            valStr = v.numericValue.toString();
          } else {
            valStr = v.toString();
          }
          // ignore: avoid_print
          print('   [${t.name}] $from -> $to | value=$valStr');
        }
      } catch (e) {
        // ignore: avoid_print
        print('-- ${t.name}: error $e');
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã in log dữ liệu ra console')),
    );
  }
}
