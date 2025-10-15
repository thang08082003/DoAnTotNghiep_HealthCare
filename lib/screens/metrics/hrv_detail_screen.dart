import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/health_metrics_providers.dart';
import '../../providers/user_provider.dart';
import 'hrv_measure_screen.dart';

import '../../data/resources/gene/app_colors.dart';
import '../../data/services/health_connect_service.dart';

class HrvDetailScreen extends ConsumerStatefulWidget {
  const HrvDetailScreen({super.key});

  @override
  ConsumerState<HrvDetailScreen> createState() => _HrvDetailScreenState();
}

enum _Range { day, week, month }

class _HrvDetailScreenState extends ConsumerState<HrvDetailScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel(
    'com.example.healthcare/hrv',
  );
  // _openMeasureScreen removed; use native _measureHrv()

  bool _loading = true;
  String? _error;
  _Range _mode = _Range.day;
  bool _isFetching = false; // re-entrancy guard
  bool _connected = false; // ensureConnected only once per mount
  DateTime? _lastLoadAt; // debounce resumed refresh
  bool _measuring = false; // UI state during native measurement
  double _measureProgress = 0; // 0..1 during measurement
  Map<String, dynamic>? _lastMeasure; // store last detailed results

  // Day: raw RMSSD points
  List<_TimedSample> _dayRmssd = const [];
  // Day: raw SDNN points (manual measurements only, no longer fetched from Health Connect)
  List<_TimedSample> _daySdnn = const [];
  // Day: pNN50
  List<_TimedSample> _dayPnn50 = const [];
  // Day: HR during measurement
  List<_TimedSample> _dayHr = const [];
  // Day: HRV Score (store as double for uniform handling)
  List<_TimedSample> _dayScore = const [];
  // Week/Month: averages
  late DateTime _weekStart;
  List<double> _weekRmssdAvg = List.filled(7, 0);
  List<double> _monthRmssdAvg = const [];

  // Week/Month: manual metrics (all samples in range – we only need aggregated stats)
  List<double> _weekPnn50 = const [];
  List<double> _weekHr = const [];
  List<double> _weekScore = const [];
  // Week/Month: daily average Score for charts
  List<double> _weekScoreAvg = List.filled(7, 0);
  List<double> _weekSdnn = const [];

  List<double> _monthPnn50 = const [];
  List<double> _monthHr = const [];
  List<double> _monthScore = const [];
  List<double> _monthScoreAvg = const [];
  List<double> _monthSdnn = const [];

  // Colors per metric
  static const Color _colorRmssd = Colors.teal;
  static const Color _colorSdnn = Colors.blueGrey; // daily only (manual)
  static const Color _colorPnn50 = Colors.orange;
  static const Color _colorHr = Colors.redAccent;
  static const Color _colorScore = Colors.purple;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weekStart = _startOfWeek(DateTime.now());
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Debounce rapid consecutive resumes (e.g., from permission/settings flows)
      final now = DateTime.now();
      if (_isFetching) return;
      if (_lastLoadAt != null &&
          now.difference(_lastLoadAt!).inMilliseconds < 1500) {
        return;
      }
      _loadAll();
    }
  }

  DateTime _startOfWeek(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return d.subtract(Duration(days: d.weekday - 1)); // Monday
  }

  Future<void> _loadAll() async {
    if (_isFetching) return;
    _isFetching = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final now = DateTime.now();

      // Day
      final dayStart = DateTime(now.year, now.month, now.day);
      // Lấy HRV từ Firestore cho ngày hiện tại (đầy đủ các trường)
      try {
        final user = await ref.read(currentUserProvider.future);
        if (user != null) {
          final col = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('hrv');
          final snap = await col
              .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart.toUtc()))
              .where('ts', isLessThan: Timestamp.fromDate(now.toUtc()))
              .get();
          final rmssdPts = <_TimedSample>[];
          final sdnnPts = <_TimedSample>[];
          final pnnPts = <_TimedSample>[];
          final hrPts = <_TimedSample>[];
          final scorePts = <_TimedSample>[];
          for (final doc in snap.docs) {
            final data = doc.data();
            final tst = data['ts'];
            if (tst is! Timestamp) continue;
            final t = tst.toDate().toLocal();
            final rmssd = (data['rmssd'] as num?)?.toDouble();
            final sdnn = (data['sdnn'] as num?)?.toDouble();
            final pnn50 = (data['pnn50'] as num?)?.toDouble();
            final hr = (data['hr'] as num?)?.toDouble();
            final score = (data['score'] as num?)?.toDouble();
            if (rmssd != null && rmssd.isFinite && rmssd > 0) {
              rmssdPts.add(_TimedSample(time: t, value: rmssd));
            }
            if (sdnn != null && sdnn.isFinite && sdnn > 0) {
              sdnnPts.add(_TimedSample(time: t, value: sdnn));
            }
            if (pnn50 != null && pnn50.isFinite && pnn50 > 0) {
              pnnPts.add(_TimedSample(time: t, value: pnn50));
            }
            if (hr != null && hr.isFinite && hr > 0) {
              hrPts.add(_TimedSample(time: t, value: hr));
            }
            if (score != null && score.isFinite && score >= 0) {
              scorePts.add(_TimedSample(time: t, value: score));
            }
          }
          rmssdPts.sort((a, b) => a.time.compareTo(b.time));
          sdnnPts.sort((a, b) => a.time.compareTo(b.time));
          pnnPts.sort((a, b) => a.time.compareTo(b.time));
          hrPts.sort((a, b) => a.time.compareTo(b.time));
          scorePts.sort((a, b) => a.time.compareTo(b.time));
          _dayRmssd = rmssdPts;
          _daySdnn = sdnnPts;
          _dayPnn50 = pnnPts;
          _dayHr = hrPts;
          _dayScore = scorePts;
        } else {
          _dayRmssd = const [];
          _daySdnn = const [];
          _dayPnn50 = const [];
          _dayHr = const [];
          _dayScore = const [];
        }
      } catch (_) {
        _dayRmssd = const [];
        _daySdnn = const [];
        _dayPnn50 = const [];
        _dayHr = const [];
        _dayScore = const [];
      }
      // _daySdnn now only accumulates manual results (see _measureHrv)

      // Week
      final weekStart = _startOfWeek(now);
      final weekEnd = weekStart.add(const Duration(days: 7));
      _weekStart = weekStart;
      // Trung bình theo ngày trong tuần từ Firestore (Score)
      try {
        final user = await ref.read(currentUserProvider.future);
        if (user != null) {
          final col = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('hrv');
          final snap = await col
              .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart.toUtc()))
              .where('ts', isLessThan: Timestamp.fromDate(weekEnd.toUtc()))
              .get();
          final days = 7;
          final sums = List<double>.filled(days, 0);
          final counts = List<int>.filled(days, 0);
          for (final doc in snap.docs) {
            final d = doc.data();
            final tst = d['ts'];
            final score = (d['score'] as num?)?.toDouble();
            if (tst is! Timestamp || score == null || !score.isFinite || score < 0) continue;
            final idx = tst.toDate().toLocal().difference(weekStart).inDays;
            if (idx < 0 || idx >= days) continue;
            sums[idx] += score;
            counts[idx] += 1;
          }
          _weekScoreAvg = [
            for (int i = 0; i < days; i++) counts[i] == 0 ? 0 : (sums[i] / counts[i])
          ];
        } else {
          _weekScoreAvg = List<double>.filled(7, 0);
        }
      } catch (_) {
        _weekScoreAvg = List<double>.filled(7, 0);
      }

      // Month
      final mStart = DateTime(now.year, now.month, 1);
      final mEnd = DateTime(now.year, now.month + 1, 1);
      try {
        final user = await ref.read(currentUserProvider.future);
        if (user != null) {
          final col = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('hrv');
          final snap = await col
              .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(mStart.toUtc()))
              .where('ts', isLessThan: Timestamp.fromDate(mEnd.toUtc()))
              .get();
          final days = mEnd.difference(mStart).inDays;
          final sums = List<double>.filled(days, 0);
          final counts = List<int>.filled(days, 0);
          for (final doc in snap.docs) {
            final d = doc.data();
            final tst = d['ts'];
            final score = (d['score'] as num?)?.toDouble();
            if (tst is! Timestamp || score == null || !score.isFinite || score < 0) continue;
            final idx = tst.toDate().toLocal().difference(mStart).inDays;
            if (idx < 0 || idx >= days) continue;
            sums[idx] += score;
            counts[idx] += 1;
          }
          _monthScoreAvg = [
            for (int i = 0; i < days; i++) counts[i] == 0 ? 0 : (sums[i] / counts[i])
          ];
        } else {
          _monthScoreAvg = const [];
        }
      } catch (_) {
        _monthScoreAvg = const [];
      }

      // Fetch manual measurement metrics (pNN50 / HR / Score) from Firestore for week & month
      try {
        final user = await ref.read(currentUserProvider.future);
        if (user != null) {
          final hrvCol = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('hrv');

          // Week range query
          final weekSnap = await hrvCol
              .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart.toUtc()))
              .where('ts', isLessThan: Timestamp.fromDate(weekEnd.toUtc()))
              .get();
          final wP = <double>[];
          final wH = <double>[];
          final wS = <double>[];
          final wSd = <double>[];
          for (final doc in weekSnap.docs) {
            final d = doc.data();
            final pnn50 = (d['pnn50'] as num?)?.toDouble();
            final hr = (d['hr'] as num?)?.toDouble();
            final score = (d['score'] as num?)?.toDouble();
            final sdnn = (d['sdnn'] as num?)?.toDouble();
            if (pnn50 != null && pnn50.isFinite) wP.add(pnn50);
            if (hr != null && hr.isFinite) wH.add(hr);
            if (score != null && score.isFinite) wS.add(score);
            if (sdnn != null && sdnn.isFinite) wSd.add(sdnn);
          }
          _weekPnn50 = wP;
          _weekHr = wH;
          _weekScore = wS;
          _weekSdnn = wSd;

          // Month range query
          final monthSnap = await hrvCol
              .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(mStart.toUtc()))
              .where('ts', isLessThan: Timestamp.fromDate(mEnd.toUtc()))
              .get();
          final mP = <double>[];
          final mH = <double>[];
          final mS = <double>[];
          final mSd = <double>[];
          for (final doc in monthSnap.docs) {
            final d = doc.data();
            final pnn50 = (d['pnn50'] as num?)?.toDouble();
            final hr = (d['hr'] as num?)?.toDouble();
            final score = (d['score'] as num?)?.toDouble();
            final sdnn = (d['sdnn'] as num?)?.toDouble();
            if (pnn50 != null && pnn50.isFinite) mP.add(pnn50);
            if (hr != null && hr.isFinite) mH.add(hr);
            if (score != null && score.isFinite) mS.add(score);
            if (sdnn != null && sdnn.isFinite) mSd.add(sdnn);
          }
          _monthPnn50 = mP;
          _monthHr = mH;
          _monthScore = mS;
          _monthSdnn = mSd;
        }
      } catch (_) {
        // Ignore Firestore errors for manual metrics to not block main data
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } finally {
      _isFetching = false;
      _lastLoadAt = DateTime.now();
    }
  }

  // daily avg logic moved to repository via provider

  (double min, double max, double avg) _summary(List<double> values) {
    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return (0, 0, 0);
    nonZero.sort();
    final min = nonZero.first;
    final max = nonZero.last;
    final avg = nonZero.reduce((a, b) => a + b) / nonZero.length;
    return (min, max, avg);
  }

  Future<void> _measureHrv() async {
    if (_measuring) return;
    // Request camera permission
    final camGranted = await Permission.camera.request().isGranted;
    if (!camGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần quyền camera để đo HRV')),
        );
      }
      return;
    }
    // Call into native (Android) to run camera + ppg_hrv.py via Chaquopy or similar
    try {
      setState(() {
        _measuring = true;
        _measureProgress = 0;
        _lastMeasure = null;
      });
      // Fake progress locally based on durationSec
      const durationSec = 60;
      final start = DateTime.now();
      Future.doWhile(() async {
        if (!_measuring) return false;
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        setState(
          () => _measureProgress = (elapsed / (durationSec * 1000)).clamp(
            0.0,
            1.0,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
        return _measureProgress < 0.999;
      });
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'measureHrv',
        {'durationSec': durationSec, 'useFlash': true},
      );
      if (result != null) {
        final rmssd = (result['rmssd'] as num?)?.toDouble();
        final sdnn = (result['sdnn'] as num?)?.toDouble();
        final pnn50 = (result['pnn50'] as num?)?.toDouble();
        final hr = (result['hr'] as num?)?.toDouble();
        final score = (result['hrvScore'] as num?)?.toInt();
        final level = result['hrvLevel']?.toString();
        _lastMeasure = {
          'rmssd': rmssd,
          'sdnn': sdnn,
          'pnn50': pnn50,
          'hr': hr,
          'hrvScore': score,
          'hrvLevel': level,
        };
        if (mounted) {
          // no dialog; results will be rendered inside the circular button
        }
        // Optionally add a point to the day series for visualization
        if (rmssd != null && rmssd.isFinite) {
          final now = DateTime.now();
          setState(() {
            _dayRmssd = List<_TimedSample>.from(_dayRmssd)
              ..add(_TimedSample(time: now, value: rmssd))
              ..sort((a, b) => a.time.compareTo(b.time));
            if (sdnn != null && sdnn.isFinite) {
              _daySdnn = List<_TimedSample>.from(_daySdnn)
                ..add(_TimedSample(time: now, value: sdnn))
                ..sort((a, b) => a.time.compareTo(b.time));
            }
            if (pnn50 != null && pnn50.isFinite) {
              _dayPnn50 = List<_TimedSample>.from(_dayPnn50)
                ..add(_TimedSample(time: now, value: pnn50))
                ..sort((a, b) => a.time.compareTo(b.time));
            }
            if (hr != null && hr.isFinite) {
              _dayHr = List<_TimedSample>.from(_dayHr)
                ..add(_TimedSample(time: now, value: hr))
                ..sort((a, b) => a.time.compareTo(b.time));
            }
            if (score != null) {
              _dayScore = List<_TimedSample>.from(_dayScore)
                ..add(_TimedSample(time: now, value: score.toDouble()))
                ..sort((a, b) => a.time.compareTo(b.time));
            }
          });
          // Persist manual measurement (rmssd + sdnn if present)
          try {
            final user = await ref.read(currentUserProvider.future);
            if (user != null) {
              await ref
                  .read(healthMetricsRepositoryProvider)
                  .saveManualHrv(
                    user.uid,
                    rmssd: rmssd,
                    sdnn: sdnn,
                    pnn50: pnn50,
                    hr: hr,
                    score: score,
                    level: level,
                    ts: now,
                  );
            }
          } catch (_) {}
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đo HRV: ${e.message ?? e.code}')),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chức năng đo HRV sẽ sớm được kích hoạt (cần tích hợp camera + Python).',
            ),
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _measuring = false;
          _measureProgress = 1;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HRV'),
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSegmentedControl<_Range>(
                      groupValue: _mode,
                      onValueChanged: (r) => setState(() => _mode = r),
                      children: const {
                        _Range.day: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('D'),
                        ),
                        _Range.week: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('W'),
                        ),
                        _Range.month: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('M'),
                        ),
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBody()),
                ],
              ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _Range.day:
        return _buildDay();
      case _Range.week:
        return _buildWeek();
      case _Range.month:
        return _buildMonth();
    }
  }

  Widget _buildDay() {
    // Dùng score cho biểu đồ dạng cột
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    // Bucket theo giờ 0..23
    final buckets = List<List<double>>.generate(24, (_) => []);
    for (final s in _dayScore) {
      final hour = s.time.difference(start).inHours;
      if (hour >= 0 && hour < 24) buckets[hour].add(s.value);
    }
    final hourlyAvg = buckets
        .map((b) => b.isEmpty ? 0.0 : (b.reduce((a, b2) => a + b2) / b.length))
        .toList();
    final bars = <BarChartGroupData>[];
    for (int i = 0; i < 24; i++) {
      final y = hourlyAvg[i];
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: y,
              color: AppColors.primaryColor,
              width: 8,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }
    // Tính Min/Avg/Max cho RMSSD theo dữ liệu trong ngày
    final rmssdValues = _dayRmssd.map((e) => e.value).toList();
    final (rmssdMin, rmssdMax, rmssdAvg) = _summary(rmssdValues);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildCircularMeasureButton()),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: bars.isEmpty
                ? const Center(child: Text('Chưa có dữ liệu'))
                : BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: 100,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                        horizontalInterval: 20,
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipRoundedRadius: 8,
                          getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                            '${rod.toY.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                            reservedSize: 20,
                            getTitlesWidget: (v, meta) {
                              final tick = v.toInt();
                              if (tick == 0 || tick == 6 || tick == 12 || tick == 18) {
                                return Text('${tick}h', style: const TextStyle(fontSize: 10));
                              }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                      ),
                      barGroups: bars,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _summarySectionDay(rmssdMin, rmssdMax, rmssdAvg),
        ],
      ),
    );
  }

  Widget _buildCircularMeasureButton() {
    final size = 180.0;
    final progress = _measuring ? _measureProgress : 0.0; // không hiển thị vòng quay trước khi đo
    return GestureDetector(
      onTap: _measuring
          ? null
          : () async {
              final res = await Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(builder: (_) => const HrvMeasureScreen()),
              );
              if (res != null) {
                setState(() => _lastMeasure = res);
                try {
                  final rmssd = (res['rmssd'] as num?)?.toDouble();
                  final sdnn = (res['sdnn'] as num?)?.toDouble();
                  final pnn50 = (res['pnn50'] as num?)?.toDouble();
                  final hr = (res['hr'] as num?)?.toDouble();
                  final score = (res['hrvScore'] as num?)?.toInt();
                  final level = res['hrvLevel']?.toString();
                  final now = DateTime.now();
                  final user = await ref.read(currentUserProvider.future);
                  if (user != null) {
                    await ref.read(healthMetricsRepositoryProvider).saveManualHrv(
                          user.uid,
                          rmssd: rmssd,
                          sdnn: sdnn,
                          pnn50: pnn50,
                          hr: hr,
                          score: score,
                          level: level,
                          ts: now,
                        );
                  }
                  // Cập nhật hiển thị nhanh trong ngày
                  if (score != null) {
                    setState(() {
                      _dayScore = List<_TimedSample>.from(_dayScore)
                        ..add(_TimedSample(time: now, value: score.toDouble()))
                        ..sort((a, b) => a.time.compareTo(b.time));
                    });
                  }
                  await _loadAll();
                } catch (_) {}
              }
            },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: progress > 0
                ? CircularProgressIndicator(
                    value: progress,
              strokeWidth: 10,
              backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                  )
                : const SizedBox.shrink(),
          ),
          Container(
            width: size - 24,
            height: size - 24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _measuring
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.camera_alt, color: Colors.black54),
                      SizedBox(height: 6),
                      Text(
                        'Đang đo HRV',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : (_lastMeasure == null
                      ? const Text(
                          'Đo HRV',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : _buildMeasureResult()),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasureResult() {
    final m = _lastMeasure!;
    double? rmssd = (m['rmssd'] as num?)?.toDouble();
    double? sdnn = (m['sdnn'] as num?)?.toDouble();
    double? pnn50 = (m['pnn50'] as num?)?.toDouble();
    double? hr = (m['hr'] as num?)?.toDouble();
    int? score = m['hrvScore'] as int?;
    String? level = m['hrvLevel'] as String?;
    String fmt(double? v, String unit) =>
        v == null || v.isNaN ? '-' : '${v.toStringAsFixed(0)}$unit';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'HRV ${score ?? 0}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 6),
        Text('RMSSD ${fmt(rmssd, ' ms')}'),
        Text('SDNN ${fmt(sdnn, ' ms')}'),
        Text('pNN50 ${fmt(pnn50, ' %')}'),
        Text('HR ${fmt(hr, ' bpm')}'),
        if (level != null)
          Text('(${level})', style: const TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _buildWeek() {
    final bars = <BarChartGroupData>[];
    for (int i = 0; i < 7; i++) {
      final double y = _weekScoreAvg.length > i ? _weekScoreAvg[i] : 0.0;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: y,
              color: AppColors.primaryColor,
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }
    final (minV, maxV, avgV) = _summary(_weekScoreAvg);
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = v.round();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        final d = _weekStart.add(Duration(days: i));
                        return Text('${d.day}');
                      },
                    ),
                  ),
                ),
                barGroups: bars,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _summarySectionWeek(minV, maxV, avgV),
        ],
      ),
    );
  }

  Widget _buildMonth() {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    final bars = <BarChartGroupData>[];
    for (int i = 0; i < _monthScoreAvg.length; i++) {
      final double y = _monthScoreAvg[i];
      bars.add(
        BarChartGroupData(
          x: i + 1,
          barRods: [
            BarChartRodData(
              toY: y,
              color: AppColors.primaryColor,
              width: 8,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }
    final (minV, maxV, avgV) = _summary(_monthScoreAvg);
    const ticks = {1, 7, 14, 21, 28};
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final d = v.round();
                        if (ticks.contains(d)) return Text('$d');
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                barGroups: bars,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _summarySectionMonth(minV, maxV, avgV),
        ],
      ),
    );
  }

  // (legacy helper removed: formatting now handled in _buildSummaryTable extension)

  Widget _wrapSummary(String title, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _summarySectionDay(double rmssdMin, double rmssdMax, double rmssdAvg) {
    final sdnnStats = _summary(_daySdnn.map((e) => e.value).toList());
    final pnnStats = _summary(_dayPnn50.map((e) => e.value).toList());
    final hrStats = _summary(_dayHr.map((e) => e.value).toList());
    final scoreStats = _summary(_dayScore.map((e) => e.value).toList());
    final metrics = <_MetricSummary>[
      _MetricSummary('RMSSD', rmssdMin, rmssdAvg, rmssdMax, 'ms', _colorRmssd),
      _MetricSummary(
        'SDNN',
        sdnnStats.$1,
        sdnnStats.$3,
        sdnnStats.$2,
        'ms',
        _colorSdnn,
      ),
      _MetricSummary(
        'pNN50',
        pnnStats.$1,
        pnnStats.$3,
        pnnStats.$2,
        '%',
        _colorPnn50,
      ),
      _MetricSummary('HR', hrStats.$1, hrStats.$3, hrStats.$2, 'bpm', _colorHr),
      _MetricSummary(
        'Score',
        scoreStats.$1,
        scoreStats.$3,
        scoreStats.$2,
        '',
        _colorScore,
      ),
    ];
    return _wrapSummary('Tổng kết hàng ngày', [
      _buildSummaryTable(metrics, showHeaders: true),
      if (_lastMeasure?['hrvLevel'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Level: ${_lastMeasure!['hrvLevel']}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
    ]);
  }

  Widget _summarySectionWeek(
    double rmssdMin,
    double rmssdMax,
    double rmssdAvg,
  ) {
    final sdnnStats = _summary(_weekSdnn);
    final pnnStats = _summary(_weekPnn50);
    final hrStats = _summary(_weekHr);
    final scoreStats = _summary(_weekScore);
    final metrics = <_MetricSummary>[
      _MetricSummary('RMSSD', rmssdMin, rmssdAvg, rmssdMax, 'ms', _colorRmssd),
      _MetricSummary('SDNN', sdnnStats.$1, sdnnStats.$3, sdnnStats.$2, 'ms', _colorSdnn),
      _MetricSummary(
        'pNN50',
        pnnStats.$1,
        pnnStats.$3,
        pnnStats.$2,
        '%',
        _colorPnn50,
      ),
      _MetricSummary('HR', hrStats.$1, hrStats.$3, hrStats.$2, 'bpm', _colorHr),
      _MetricSummary(
        'Score',
        scoreStats.$1,
        scoreStats.$3,
        scoreStats.$2,
        '',
        _colorScore,
      ),
    ];
    return _wrapSummary('Tổng kết hàng tuần', [_buildSummaryTable(metrics)]);
  }

  Widget _summarySectionMonth(
    double rmssdMin,
    double rmssdMax,
    double rmssdAvg,
  ) {
    final sdnnStats = _summary(_monthSdnn);
    final pnnStats = _summary(_monthPnn50);
    final hrStats = _summary(_monthHr);
    final scoreStats = _summary(_monthScore);
    final metrics = <_MetricSummary>[
      _MetricSummary('RMSSD', rmssdMin, rmssdAvg, rmssdMax, 'ms', _colorRmssd),
      _MetricSummary('SDNN', sdnnStats.$1, sdnnStats.$3, sdnnStats.$2, 'ms', _colorSdnn),
      _MetricSummary(
        'pNN50',
        pnnStats.$1,
        pnnStats.$3,
        pnnStats.$2,
        '%',
        _colorPnn50,
      ),
      _MetricSummary('HR', hrStats.$1, hrStats.$3, hrStats.$2, 'bpm', _colorHr),
      _MetricSummary(
        'Score',
        scoreStats.$1,
        scoreStats.$3,
        scoreStats.$2,
        '',
        _colorScore,
      ),
    ];
    return _wrapSummary('Tổng kết hàng tháng', [_buildSummaryTable(metrics)]);
  }
}

class _MetricSummary {
  final String name;
  final double min;
  final double avg;
  final double max;
  final String unit;
  final Color color;
  const _MetricSummary(
    this.name,
    this.min,
    this.avg,
    this.max,
    this.unit,
    this.color,
  );
}

extension on double {
  String fmt(String unit) => this == 0
      ? '-'
      : '${toStringAsFixed(0)}${unit.isNotEmpty ? ' $unit' : ''}';
}

Widget _buildSummaryTable(
  List<_MetricSummary> metrics, {
  bool showHeaders = true,
}) {
  // We intentionally omit textual headers (min/avg/max) when showHeaders == false
  return Table(
    columnWidths: const {
      0: FlexColumnWidth(1.6),
      1: FlexColumnWidth(1),
      2: FlexColumnWidth(1),
      3: FlexColumnWidth(1),
    },
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    children: [
      if (showHeaders)
        const TableRow(
          children: [
            SizedBox(),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(
                  'Min',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(
                  'Avg',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(
                  'Max',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      for (final m in metrics)
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: m.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${m.name}${m.unit.isNotEmpty ? ' (${m.unit})' : ''}',
                      style: TextStyle(
                        color: m.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Text(
                m.min.fmt(m.unit),
                style: TextStyle(color: m.color, fontSize: 13),
              ),
            ),
            Center(
              child: Text(
                m.avg.fmt(m.unit),
                style: TextStyle(color: m.color, fontSize: 13),
              ),
            ),
            Center(
              child: Text(
                m.max.fmt(m.unit),
                style: TextStyle(color: m.color, fontSize: 13),
              ),
            ),
          ],
        ),
    ],
  );
}

class _TimedSample {
  final DateTime time;
  final double value;
  const _TimedSample({required this.time, required this.value});
}
