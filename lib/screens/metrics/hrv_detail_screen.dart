import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health/health.dart';

import '../../data/resources/gene/app_colors.dart';
import '../../data/services/health_connect_service.dart';

class HrvDetailScreen extends StatefulWidget {
  const HrvDetailScreen({super.key});

  @override
  State<HrvDetailScreen> createState() => _HrvDetailScreenState();
}

enum _Range { day, week, month }

class _HrvDetailScreenState extends State<HrvDetailScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel(
    'com.example.healthcare/hrv',
  );

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
  // Week/Month: averages
  late DateTime _weekStart;
  List<double> _weekRmssdAvg = List.filled(7, 0);
  List<double> _monthRmssdAvg = const [];

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
      final svc = GoogleFitService();
      if (!_connected) {
        try {
          final ok = await svc.ensureConnected();
          _connected = ok;
        } catch (e) {
          // if ensureConnected fails (e.g., missing app/permissions), surface error but avoid endless loops
          _connected = false;
          rethrow;
        }
      }
      final now = DateTime.now();

      // Day
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayPts = await svc.getData(
        types: const [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
        start: dayStart,
        end: now,
      );
      _dayRmssd =
          dayPts
              .map((p) {
                final v = p.value;
                if (v is NumericHealthValue) {
                  return _TimedSample(
                    time: p.dateFrom,
                    value: v.numericValue.toDouble(),
                  );
                }
                return null;
              })
              .whereType<_TimedSample>()
              .toList()
            ..sort((a, b) => a.time.compareTo(b.time));

      // Week
      final weekStart = _startOfWeek(now);
      final weekEnd = weekStart.add(const Duration(days: 7));
      _weekStart = weekStart;
      _weekRmssdAvg = await _dailyAvgRmssd(svc, weekStart, weekEnd);

      // Month
      final mStart = DateTime(now.year, now.month, 1);
      final mEnd = DateTime(now.year, now.month + 1, 1);
      _monthRmssdAvg = await _dailyAvgRmssd(svc, mStart, mEnd);

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

  Future<List<double>> _dailyAvgRmssd(
    GoogleFitService svc,
    DateTime start,
    DateTime end,
  ) async {
    final days = end.difference(start).inDays;
    if (days <= 0) return const <double>[];
    final pts = await svc.getData(
      types: const [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
      start: start,
      end: end,
    );
    final sums = List<double>.filled(days, 0);
    final counts = List<int>.filled(days, 0);
    for (final p in pts) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final idx = p.dateFrom.difference(start).inDays;
      if (idx < 0 || idx >= days) continue;
      sums[idx] += v.numericValue.toDouble();
      counts[idx] += 1;
    }
    return [
      for (int i = 0; i < days; i++) counts[i] == 0 ? 0 : (sums[i] / counts[i]),
    ];
  }

  // Previously used to map RMSSD to a score scale; no longer needed as we plot RMSSD directly.

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
          setState(() {
            _dayRmssd = List<_TimedSample>.from(_dayRmssd)
              ..add(_TimedSample(time: DateTime.now(), value: rmssd))
              ..sort((a, b) => a.time.compareTo(b.time));
          });
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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final spots = <FlSpot>[];
    for (final s in _dayRmssd) {
      final x = s.time.difference(start).inMinutes / 60.0;
      final y = s.value;
      spots.add(FlSpot(x.clamp(0, 24), y));
    }
    final (minV, maxV, avgV) = _summary(spots.map((e) => e.y).toList());
    const double minY = 0.0;
    const double maxY = 200.0;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildCircularMeasureButton()),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 24,
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20.0,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50.0,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) => Text('${v.round()}'),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 6.0,
                      getTitlesWidget: (v, m) {
                        final iv = v.round();
                        if ({0, 6, 12, 18, 24}.contains(iv))
                          return Text('${iv}h');
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: false,
                    color: AppColors.primaryColor,
                    dotData: const FlDotData(show: false),
                    spots: spots,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _summaryCard('Tổng kết hàng ngày', minV, maxV, avgV),
        ],
      ),
    );
  }

  Widget _buildCircularMeasureButton() {
    final size = 180.0;
    final progress = _measuring
        ? _measureProgress
        : (_lastMeasure == null ? 0.0 : 1.0);
    return GestureDetector(
      onTap: _measuring ? null : _measureHrv,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress == 0 ? null : progress,
              strokeWidth: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _measuring ? AppColors.primaryColor : Colors.teal,
              ),
            ),
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
                          'HRV',
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
    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      final double y = _weekRmssdAvg.length > i ? _weekRmssdAvg[i] : 0.0;
      if (y > 0) spots.add(FlSpot(i.toDouble(), y));
    }
    final (minV, maxV, avgV) = _summary(spots.map((e) => e.y).toList());
    const double minY = 0.0;
    const double maxY = 200.0;
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20.0,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50.0,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) => Text('${v.round()}'),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (v, m) {
                        final i = v.round();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        final d = _weekStart.add(Duration(days: i));
                        return Text('${d.day}');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: false,
                    color: AppColors.primaryColor,
                    dotData: const FlDotData(show: false),
                    spots: spots,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _summaryCard('Tổng kết hàng tuần', minV, maxV, avgV),
        ],
      ),
    );
  }

  Widget _buildMonth() {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    final spots = <FlSpot>[];
    for (int i = 0; i < _monthRmssdAvg.length; i++) {
      final double y = _monthRmssdAvg[i];
      if (y > 0) spots.add(FlSpot((i + 1).toDouble(), y));
    }
    final (minV, maxV, avgV) = _summary(spots.map((e) => e.y).toList());
    const ticks = {1, 7, 14, 21, 28};
    const double minY = 0.0;
    const double maxY = 200.0;
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: days.toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20.0,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50.0,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) => Text('${v.round()}'),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (v, m) {
                        final d = v.round();
                        if (ticks.contains(d)) return Text('$d');
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: false,
                    color: AppColors.primaryColor,
                    dotData: const FlDotData(show: true),
                    spots: spots,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _summaryCard('Tổng kết hàng tháng', minV, maxV, avgV),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double minV, double maxV, double avgV) {
    Widget cell(String label, double v) => Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          v == 0 ? '-' : v.toStringAsFixed(0),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          cell('Tối thiểu', minV),
          cell('Trung bình', avgV),
          cell('Tối đa', maxV),
        ],
      ),
    );
  }
}

class _TimedSample {
  final DateTime time;
  final double value;
  const _TimedSample({required this.time, required this.value});
}
