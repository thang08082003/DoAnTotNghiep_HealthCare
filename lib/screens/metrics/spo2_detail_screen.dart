import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/health_connect_service.dart';
import 'package:health/health.dart';

class Spo2DetailScreen extends StatefulWidget {
  const Spo2DetailScreen({super.key});

  @override
  State<Spo2DetailScreen> createState() => _Spo2DetailScreenState();
}

enum _Spo2Range { day, week, month }

class _Spo2DetailScreenState extends State<Spo2DetailScreen> {
  bool _loading = true;
  String? _error;
  _Spo2Range _mode = _Spo2Range.day;

  // chart data
  List<FlSpot> _daySpots = const [];
  List<FlSpot> _weekSpots = const [];
  List<FlSpot> _monthSpots = const [];

  double? _dayMin, _dayMax, _dayAvg;
  double? _weekMin, _weekMax, _weekAvg;
  double? _monthMin, _monthMax, _monthAvg;

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
      final now = DateTime.now();

      // Day (last 24h)
      final dayStart = now.subtract(const Duration(hours: 24));
      final dayData = await _fetchRawSpo2(svc, dayStart, now);
      final daySpots = _mapToDaySpots(dayData, dayStart);
      final dayStats = _calcStats(dayData);

      // Week (Mon..Sun current week)
      final monday = _startOfWeek(now);
      final sunday = monday.add(const Duration(days: 7));
      final weekData = await _fetchRawSpo2(svc, monday, sunday);
      final weekDailyAverages = _dailyAverages(weekData, monday, 7);
      final weekSpots = List<FlSpot>.generate(7, (i) {
        final v = weekDailyAverages[i];
        return FlSpot(i.toDouble(), (v ?? 0));
      });
      final weekStats = _calcStats(weekData);

      // Month
      final firstDay = DateTime(now.year, now.month, 1);
      final firstNextMonth = DateTime(now.year, now.month + 1, 1);
      final monthData = await _fetchRawSpo2(svc, firstDay, firstNextMonth);
      final lastDay = firstNextMonth.subtract(const Duration(days: 1)).day;
      final monthDailyAverages = _dailyAverages(monthData, firstDay, lastDay);
      final monthSpots = List<FlSpot>.generate(lastDay, (i) {
        final dayIndex = i + 1;
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

  Future<List<HealthDataPoint>> _fetchRawSpo2(
    GoogleFitService svc,
    DateTime start,
    DateTime end,
  ) async {
    return svc.getData(
      start: start,
      end: end,
      types: const [HealthDataType.BLOOD_OXYGEN],
    );
  }

  List<FlSpot> _mapToDaySpots(List<HealthDataPoint> data, DateTime start) {
    final List<FlSpot> pts = [];
    for (final d in data) {
      final t = d.dateFrom;
      final val = d.value;
      if (val is NumericHealthValue) {
        final num nv = val.numericValue;
        final v = nv.toDouble();
        if (v <= 0) continue;
        final hours = t.difference(start).inMinutes / 60.0;
        if (hours >= 0 && hours <= 24) {
          pts.add(FlSpot(hours, v));
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
        final v = nv.toDouble();
        if (v <= 0) continue;
        final dayIndex = d.dateFrom.difference(startDay).inDays;
        if (dayIndex >= 0 && dayIndex < count) {
          buckets[dayIndex].add(v);
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
        final x = nv.toDouble();
        if (x > 0) values.add(x);
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
      appBar: AppBar(title: const Text('SpO₂')),
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
          child: CupertinoSegmentedControl<_Spo2Range>(
            groupValue: _mode,
            onValueChanged: (m) => setState(() => _mode = m),
            children: {
              _Spo2Range.day: SizedBox(
                width: segWidth,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('D'),
                  ),
                ),
              ),
              _Spo2Range.week: SizedBox(
                width: segWidth,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('W'),
                  ),
                ),
              ),
              _Spo2Range.month: SizedBox(
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
      case _Spo2Range.day:
        return _ChartWithSummary(
          title: 'Tổng kết hàng ngày',
          chart: _buildDayChart(),
          min: _dayMin,
          max: _dayMax,
          avg: _dayAvg,
          unit: '%',
        );
      case _Spo2Range.week:
        return _ChartWithSummary(
          title: 'Tổng kết hàng tuần',
          chart: _buildWeekChart(),
          min: _weekMin,
          max: _weekMax,
          avg: _weekAvg,
          unit: '%',
        );
      case _Spo2Range.month:
        return _ChartWithSummary(
          title: 'Tổng kết hàng tháng',
          chart: _buildMonthChart(),
          min: _monthMin,
          max: _monthMax,
          avg: _monthAvg,
          unit: '%',
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
                maxY: 100,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
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
                      interval: 20,
                      getTitlesWidget: (v, m) {
                        const eps = 1e-6;
                        final iv = v.round();
                        final isInt = (v - iv).abs() < eps;
                        if (isInt && iv % 20 == 0 && iv >= 0 && iv <= 100) {
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
                maxY: 100,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
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
                      interval: 20,
                      getTitlesWidget: (v, m) {
                        const eps = 1e-6;
                        final iv = v.round();
                        final isInt = (v - iv).abs() < eps;
                        if (isInt && iv % 20 == 0 && iv >= 0 && iv <= 100) {
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
                maxY: 100,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
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
                      interval: 20,
                      getTitlesWidget: (v, m) {
                        const eps = 1e-6;
                        final iv = v.round();
                        final isInt = (v - iv).abs() < eps;
                        if (isInt && iv % 20 == 0 && iv >= 0 && iv <= 100) {
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
  final String unit;
  const _ChartWithSummary({
    required this.title,
    required this.chart,
    required this.min,
    required this.max,
    required this.avg,
    required this.unit,
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
    final text = value == null ? '-' : '${value.toStringAsFixed(0)} $unit';
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
