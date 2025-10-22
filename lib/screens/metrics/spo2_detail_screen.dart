import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/health_connect_service.dart';
import 'package:health/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/health_metrics_providers.dart';
import '../../data/models/health_metric_models.dart';

class Spo2DetailScreen extends ConsumerStatefulWidget {
  final String? userId; // nếu có userId -> dùng Firestore (role bác sĩ)
  const Spo2DetailScreen({super.key, this.userId});

  @override
  ConsumerState<Spo2DetailScreen> createState() => _Spo2DetailScreenState();
}

enum _Spo2Range { day, week, month }

class _Spo2DetailScreenState extends ConsumerState<Spo2DetailScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  _Spo2Range _mode = _Spo2Range.day;
  bool _fetching = false;

  // chart data
  List<FlSpot> _daySpots = const [];
  List<FlSpot> _weekSpots = const [];
  List<FlSpot> _monthSpots = const [];

  // Day hourly averages for bar chart (24 values)
  List<double?> _dayHourlyAvg = const [];

  double? _dayMin, _dayMax, _dayAvg;
  double? _weekMin, _weekMax, _weekAvg;
  double? _monthMin, _monthMax, _monthAvg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    if (_fetching) return;
    _fetching = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final now = DateTime.now();
      if (widget.userId != null) {
        // Firestore (role bác sĩ)
        final repo = ref.read(healthMetricsRepositoryProvider);

        // Day
        final dayStart = DateTime(now.year, now.month, now.day);
        final daySamples = await repo
            .spo2Stream(widget.userId!, from: dayStart)
            .first;
        final daySpots = _mapFsToDaySpots(daySamples, dayStart);
        final dayStats = _calcFsStats(daySamples);
        final dayHourly = _hourlyAveragesFromSpots(daySpots);

        // Week
        final monday = _startOfWeek(now);
        final weekSamples = await repo
            .spo2Stream(widget.userId!, from: monday)
            .first;
        final weekDailyAverages = _dailyAveragesFromFs(weekSamples, monday, 7);
        final weekSpots = List<FlSpot>.generate(7, (i) {
          final v = weekDailyAverages[i];
          return FlSpot(i.toDouble(), (v ?? 0));
        });
        final weekStats = _calcFsStats(weekSamples);

        // Month
        final firstDay = DateTime(now.year, now.month, 1);
        final firstNextMonth = DateTime(now.year, now.month + 1, 1);
        final lastDay = firstNextMonth.subtract(const Duration(days: 1)).day;
        final monthSamples = await repo
            .spo2Stream(widget.userId!, from: firstDay)
            .first;
        final monthDailyAverages = _dailyAveragesFromFs(
          monthSamples,
          firstDay,
          lastDay,
        );
        final monthSpots = List<FlSpot>.generate(lastDay, (i) {
          final dayIndex = i + 1;
          final v = monthDailyAverages[i];
          return FlSpot(dayIndex.toDouble(), (v ?? 0));
        });
        final monthStats = _calcFsStats(monthSamples);

        if (!mounted) return;
        setState(() {
          _daySpots = daySpots;
          _dayMin = dayStats.min;
          _dayMax = dayStats.max;
          _dayAvg = dayStats.avg;
          _dayHourlyAvg = dayHourly;

          _weekSpots = weekSpots;
          _weekMin = weekStats.min;
          _weekMax = weekStats.max;
          _weekAvg = weekStats.avg;

          _monthSpots = monthSpots;
          _monthMin = monthStats.min;
          _monthMax = monthStats.max;
          _monthAvg = monthStats.avg;
        });
      } else {
        // Health Connect (role bệnh nhân)
        final svc = GoogleFitService();

        // Day anchored to today's 00:00 -> now
        final dayStart = DateTime(now.year, now.month, now.day);
        final dayData = await _fetchRawSpo2(svc, dayStart, now);
        final daySpots = _mapToDaySpots(dayData, dayStart);
        final dayStats = _calcStats(dayData);
        final dayHourly = _hourlyAveragesFromSpots(daySpots);

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
          _dayHourlyAvg = dayHourly;

          _weekSpots = weekSpots;
          _weekMin = weekStats.min;
          _weekMax = weekStats.max;
          _weekAvg = weekStats.avg;

          _monthSpots = monthSpots;
          _monthMin = monthStats.min;
          _monthMax = monthStats.max;
          _monthAvg = monthStats.avg;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Firestore helpers ---
  List<FlSpot> _mapFsToDaySpots(List<Spo2Sample> samples, DateTime start) {
    final List<FlSpot> pts = [];
    for (final s in samples) {
      final v = s.percentage;
      if (v <= 0) continue;
      final hours = s.ts.difference(start).inMinutes / 60.0;
      if (hours >= 0 && hours <= 24) {
        pts.add(FlSpot(hours, v));
      }
    }
    pts.sort((a, b) => a.x.compareTo(b.x));
    return pts;
  }

  List<double?> _dailyAveragesFromFs(
    List<Spo2Sample> samples,
    DateTime startDay,
    int count,
  ) {
    final buckets = List<List<double>>.generate(count, (_) => []);
    for (final s in samples) {
      final v = s.percentage;
      if (v <= 0) continue;
      final dayIndex = s.ts.difference(startDay).inDays;
      if (dayIndex >= 0 && dayIndex < count) {
        buckets[dayIndex].add(v);
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

  _Stats _calcFsStats(List<Spo2Sample> samples) {
    final values = samples
        .map((e) => e.percentage)
        .where((v) => v > 0)
        .toList();
    if (values.isEmpty) return const _Stats(null, null, null);
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;
    return _Stats(min, max, avg);
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

  // Build 24 hourly averages from scattered spots in range [0,24)
  List<double?> _hourlyAveragesFromSpots(List<FlSpot> spots) {
    final buckets = List<List<double>>.generate(24, (_) => []);
    for (final s in spots) {
      final i = s.x.floor();
      if (i >= 0 && i < 24) buckets[i].add(s.y);
    }
    return buckets
        .map((b) => b.isEmpty ? null : b.reduce((a, b) => a + b) / b.length)
        .toList();
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
      appBar: AppBar(
        title: const Text('SpO₂'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadAll,
          ),
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
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < 24; i++) {
      final y = _dayHourlyAvg.isNotEmpty ? (_dayHourlyAvg[i] ?? 0.0) : 0.0;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: y.toDouble(),
              color: AppColors.primaryColor,
              width: 6,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }
    return _ChartContainer(
      child: _daySpots.isEmpty
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
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final hour = group.x;
                      final v = rod.toY;
                      return BarTooltipItem(
                        '${v.toStringAsFixed(0)} %\n${hour}h',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
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
                barGroups: groups,
              ),
            ),
    );
  }

  Widget _buildWeekChart() {
    const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final values = List<double>.generate(7, (i) {
      final spot = _weekSpots.length > i ? _weekSpots[i] : null;
      return spot?.y ?? 0.0;
    });
    final groups = [
      for (int i = 0; i < 7; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: AppColors.primaryColor,
              width: 14,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
    ];
    return _ChartContainer(
      child: _weekSpots.isEmpty
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
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      const dayLabels = [
                        'T2',
                        'T3',
                        'T4',
                        'T5',
                        'T6',
                        'T7',
                        'CN',
                      ];
                      final idx = group.x.clamp(0, 6);
                      final label = dayLabels[idx];
                      final v = rod.toY;
                      return BarTooltipItem(
                        '${v.toStringAsFixed(0)} %\n$label',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
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
                barGroups: groups,
              ),
            ),
    );
  }

  Widget _buildMonthChart() {
    final ticks = {1, 7, 14, 21, 28};
    final groups = _monthSpots
        .map(
          (s) => BarChartGroupData(
            x: s.x.round(),
            barRods: [
              BarChartRodData(
                toY: s.y.toDouble(),
                color: AppColors.primaryColor,
                width: 8,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        )
        .toList();
    return _ChartContainer(
      child: _monthSpots.isEmpty
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
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = group.x;
                      final v = rod.toY;
                      return BarTooltipItem(
                        '${v.toStringAsFixed(0)} %\nNgày $day',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
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
                barGroups: groups,
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
