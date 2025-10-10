import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/health_connect_service.dart';
import 'package:health/health.dart';

class HeartRateDetailScreen extends StatefulWidget {
  const HeartRateDetailScreen({super.key});

  @override
  State<HeartRateDetailScreen> createState() => _HeartRateDetailScreenState();
}

enum _RangeMode { day, week, month }

class _HeartRateDetailScreenState extends State<HeartRateDetailScreen> {
  bool _loading = true;
  String? _error;

  // UI mode
  _RangeMode _mode = _RangeMode.day;

  // Chart data by mode
  List<FlSpot> _daySpots = const [];
  List<FlSpot> _weekSpots = const [];
  List<FlSpot> _monthSpots = const [];

  // Summaries
  double? _dayMin;
  double? _dayMax;
  double? _dayAvg;

  double? _weekMin;
  double? _weekMax;
  double? _weekAvg;

  double? _monthMin;
  double? _monthMax;
  double? _monthAvg;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = GoogleFitService();

      // Day range (last 24h)
      final now = DateTime.now();
      final dayStart = now.subtract(const Duration(hours: 24));
      final dayData = await _fetchRawHr(svc, dayStart, now);
      final daySpots = _mapToDaySpots(dayData, dayStart);
      final dayStats = _calcStats(dayData);

      // Week range (Mon..Sun of current week)
      final monday = _startOfWeek(now);
      final sunday = monday.add(const Duration(days: 7));
      final weekData = await _fetchRawHr(svc, monday, sunday);
      final weekDailyAverages = _dailyAverages(weekData, monday, 7);
      final weekSpots = List<FlSpot>.generate(7, (i) {
        final v = weekDailyAverages[i];
        return FlSpot(i.toDouble(), (v ?? 0));
      });
      final weekStats = _calcStats(weekData);

      // Month range (first..last day of current month)
      final firstDay = DateTime(now.year, now.month, 1);
      final firstNextMonth = DateTime(now.year, now.month + 1, 1);
      final monthData = await _fetchRawHr(svc, firstDay, firstNextMonth);
      final lastDay = firstNextMonth.subtract(const Duration(days: 1)).day;
      final monthDailyAverages = _dailyAverages(monthData, firstDay, lastDay);
      final monthSpots = List<FlSpot>.generate(lastDay, (i) {
        final dayIndex = i + 1; // 1..lastDay
        final v = monthDailyAverages[i];
        return FlSpot(dayIndex.toDouble(), (v ?? 0));
      });
      final monthStats = _calcStats(monthData);

      if (!mounted) return;
      setState(() {
        _daySpots = daySpots;
        _dayMin = dayStats.min;
        _dayMax = dayStats.max;
        _dayAvg = dayStats.avg;

        _weekSpots = weekSpots;
        _weekMin = weekStats.min;
        _weekMax = weekStats.max;
        _weekAvg = weekStats.avg;

        _monthSpots = monthSpots;
        _monthMin = monthStats.min;
        _monthMax = monthStats.max;
        _monthAvg = monthStats.avg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<HealthDataPoint>> _fetchRawHr(
    GoogleFitService svc,
    DateTime start,
    DateTime end,
  ) async {
    final data = await svc.getData(
      start: start,
      end: end,
      types: const [HealthDataType.HEART_RATE],
    );
    return data;
  }

  List<FlSpot> _mapToDaySpots(List<HealthDataPoint> data, DateTime start) {
    final List<FlSpot> pts = [];
    for (final d in data) {
      final t = d.dateFrom;
      final val = d.value;
      if (val is NumericHealthValue) {
        final num nv = val.numericValue;
        final hr = nv.toDouble();
        final hours = t.difference(start).inMinutes / 60.0;
        if (hours >= 0 && hours <= 24 && hr > 0) {
          pts.add(FlSpot(hours, hr));
        }
      }
    }
    pts.sort((a, b) => a.x.compareTo(b.x));
    return pts;
  }

  DateTime _startOfWeek(DateTime now) {
    final weekday = now.weekday; // Mon=1..Sun=7
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: weekday - 1));
  }

  // Returns list of length count, each entry is the average HR for that day index
  List<double?> _dailyAverages(
    List<HealthDataPoint> raw,
    DateTime startDay,
    int count,
  ) {
    final buckets = List<List<double>>.generate(count, (_) => []);
    for (final d in raw) {
      final val = d.value;
      if (val is NumericHealthValue) {
        final num nv = val.numericValue;
        final hr = nv.toDouble();
        if (hr <= 0) continue;
        final dayIndex = d.dateFrom.difference(startDay).inDays;
        if (dayIndex >= 0 && dayIndex < count) {
          buckets[dayIndex].add(hr);
        }
      }
    }
    return buckets
        .map(
          (list) => list.isEmpty
              ? null
              : (list.reduce((a, b) => a + b) / list.length),
        )
        .toList();
  }

  _Stats _calcStats(List<HealthDataPoint> raw) {
    final values = <double>[];
    for (final d in raw) {
      final v = d.value;
      if (v is NumericHealthValue) {
        final num nv = v.numericValue;
        final hr = nv.toDouble();
        if (hr > 0) values.add(hr);
      }
    }
    if (values.isEmpty) return const _Stats(null, null, null);
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;
    return _Stats(min, max, avg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhịp tim')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSegmented(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildChartAndSummary()),
                ],
              ),
      ),
    );
  }

  Widget _buildSegmented() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segWidth = (constraints.maxWidth / 3).clamp(0.0, double.infinity);
        return SizedBox(
          width: double.infinity,
          child: CupertinoSegmentedControl<_RangeMode>(
            groupValue: _mode,
            onValueChanged: (m) => setState(() => _mode = m),
            children: {
              _RangeMode.day: SizedBox(
                width: segWidth,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('D'),
                  ),
                ),
              ),
              _RangeMode.week: SizedBox(
                width: segWidth,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('W'),
                  ),
                ),
              ),
              _RangeMode.month: SizedBox(
                width: segWidth,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('M'),
                  ),
                ),
              ),
            },
          ),
        );
      },
    );
  }

  Widget _buildChartAndSummary() {
    switch (_mode) {
      case _RangeMode.day:
        return _ChartWithSummary(
          title: 'Tổng kết hàng ngày',
          chart: _buildDayChart(),
          min: _dayMin,
          max: _dayMax,
          avg: _dayAvg,
        );
      case _RangeMode.week:
        return _ChartWithSummary(
          title: 'Tổng kết hàng tuần',
          chart: _buildWeekChart(),
          min: _weekMin,
          max: _weekMax,
          avg: _weekAvg,
        );
      case _RangeMode.month:
        return _ChartWithSummary(
          title: 'Tổng kết hàng tháng',
          chart: _buildMonthChart(),
          min: _monthMin,
          max: _monthMax,
          avg: _monthAvg,
        );
    }
  }

  Widget _buildDayChart() {
    return _ChartContainer(
      child: _daySpots.isEmpty
          ? const Center(child: Text('Chưa có dữ liệu'))
          : LineChart(
              LineChartData(
                minX: 0,
                maxX: 24,
                minY: 0,
                maxY: 190,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final tick = v.round();
                        if (tick == 0 ||
                            tick == 6 ||
                            tick == 12 ||
                            tick == 18 ||
                            tick == 24) {
                          return Text(
                            '${tick}h',
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: 50,
                      getTitlesWidget: (v, m) {
                        const ticks = {0, 50, 100, 150, 190};
                        const eps = 1e-6;
                        final iv = v.round();
                        if ((v - iv).abs() < eps && ticks.contains(iv)) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(iv.toString()),
                          );
                        }
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
                    spots: _daySpots,
                    isCurved: false,
                    color: AppColors.primaryColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWeekChart() {
    const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return _ChartContainer(
      child: _weekSpots.isEmpty
          ? const Center(child: Text('Chưa có dữ liệu'))
          : LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 190,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        // Only render labels for exact integer ticks 0..6 to avoid duplicates
                        const eps = 1e-6;
                        final isInt = (v - v.roundToDouble()).abs() < eps;
                        if (!isInt) return const SizedBox.shrink();
                        final idx = v.toInt();
                        if (idx < 0 || idx > 6) return const SizedBox.shrink();
                        return Text(
                          dayLabels[idx],
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: 50,
                      getTitlesWidget: (v, m) {
                        const ticks = {0, 50, 100, 150, 190};
                        const eps = 1e-6;
                        final iv = v.round();
                        if ((v - iv).abs() < eps && ticks.contains(iv)) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(iv.toString()),
                          );
                        }
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
                    spots: _weekSpots,
                    isCurved: false,
                    color: AppColors.primaryColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthChart() {
    // Show ticks at 1, 7, 14, 21, 28
    final ticks = {1, 7, 14, 21, 28};
    final maxX = _monthSpots.isEmpty
        ? 30.0
        : _monthSpots.map((e) => e.x).reduce((a, b) => a > b ? a : b);
    return _ChartContainer(
      child: _monthSpots.isEmpty
          ? const Center(child: Text('Chưa có dữ liệu'))
          : LineChart(
              LineChartData(
                minX: 1,
                maxX: maxX,
                minY: 0,
                maxY: 190,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final d = v.round();
                        if (ticks.contains(d)) {
                          return Text(
                            '$d',
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: 50,
                      getTitlesWidget: (v, m) {
                        const ticks = {0, 50, 100, 150, 190};
                        const eps = 1e-6;
                        final iv = v.round();
                        if ((v - iv).abs() < eps && ticks.contains(iv)) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(iv.toString()),
                          );
                        }
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
                    spots: _monthSpots,
                    isCurved: false,
                    color: AppColors.primaryColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ChartContainer extends StatelessWidget {
  final Widget child;
  const _ChartContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _ChartWithSummary extends StatelessWidget {
  final String title;
  final Widget chart;
  final double? min;
  final double? max;
  final double? avg;
  const _ChartWithSummary({
    required this.title,
    required this.chart,
    required this.min,
    required this.max,
    required this.avg,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 240, child: chart),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('Tối đa', max),
              _summaryItem('Tối thiểu', min),
              _summaryItem('Trung bình', avg),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryItem(String label, double? value) {
    final text = value == null ? '-' : '${value.toStringAsFixed(0)} bpm';
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Stats {
  final double? min;
  final double? max;
  final double? avg;
  const _Stats(this.min, this.max, this.avg);
}
