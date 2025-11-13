import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/hrv/hrv_viewmodel.dart';
import '../../data/domain/metrics_aggregate.dart';
import '../../components/chart/chart_container.dart';
import '../../components/metrics/metrics_segmented.dart';
import 'hrv_measure_screen.dart';
// removed repository/user imports as saving now handled within HrvMeasureScreen

class HrvDetailScreen extends ConsumerStatefulWidget {
  final String? userId; // Nếu có userId: xem dữ liệu HRV của bệnh nhân
  const HrvDetailScreen({super.key, this.userId});

  @override
  ConsumerState<HrvDetailScreen> createState() => _HrvDetailScreenState();
}

enum _HrvRange { day, week, month }

class _HrvDetailScreenState extends ConsumerState<HrvDetailScreen>
    with WidgetsBindingObserver {
  _HrvRange _mode = _HrvRange.day;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(hrvViewModelProvider(widget.userId).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAgg = ref.watch(hrvViewModelProvider(widget.userId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('HRV'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Đo HRV',
            icon: const Icon(Icons.monitor_heart),
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => HrvMeasureScreen(userId: widget.userId),
                ),
              );
              if (!mounted) return;
              if (saved == true) {
                ref
                    .read(hrvViewModelProvider(widget.userId).notifier)
                    .refresh();
              }
            },
          ),
          IconButton(
            onPressed: () => ref
                .read(hrvViewModelProvider(widget.userId).notifier)
                .refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncAgg.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Text(
              e.toString(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
          data: (agg) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSegmented(),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(agg)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmented() {
    return MetricsSegmented(
      value: _mode == _HrvRange.day
          ? MetricsRange.day
          : _mode == _HrvRange.week
          ? MetricsRange.week
          : MetricsRange.month,
      onChanged: (r) => setState(() {
        _mode = r == MetricsRange.day
            ? _HrvRange.day
            : r == MetricsRange.week
            ? _HrvRange.week
            : _HrvRange.month;
      }),
    );
  }

  Widget _buildBody(HrvAggregate agg) {
    switch (_mode) {
      case _HrvRange.day:
        return _buildDay(agg);
      case _HrvRange.week:
        return _buildWeek(agg);
      case _HrvRange.month:
        return _buildMonth(agg);
    }
  }

  // Day: hourly HRV score (0..100) bar chart + RMSSD summary
  Widget _buildDay(HrvAggregate agg) {
    final scores = agg.dayHourlyScore;
    final bars = <BarChartGroupData>[
      for (int i = 0; i < 24; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: i < scores.length ? scores[i].clamp(0, 100) : 0,
              width: 8,
              borderRadius: BorderRadius.circular(2),
              color: AppColors.primaryColor,
            ),
          ],
        ),
    ];

    final rmssd = agg.dayRmssd;
    final rmssdMin = rmssd.min ?? 0;
    final rmssdMax = rmssd.max ?? 0;
    final rmssdAvg = rmssd.avg ?? 0;
    final pnn = agg.dayPnn50;
    final hr = agg.dayHr;
    final sc = agg.dayScore;

    return SingleChildScrollView(
      child: Column(
        children: [
          ChartContainer(
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 20,
                        getTitlesWidget: (v, m) {
                          final iv = v.round();
                          if (iv % 20 == 0 && iv >= 0 && iv <= 100) {
                            return Text(iv.toString());
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (v, m) {
                          final tick = v.toInt();
                          if (tick == 0 ||
                              tick == 6 ||
                              tick == 12 ||
                              tick == 18) {
                            return Text(
                              '${tick}h',
                              style: const TextStyle(fontSize: 10),
                            );
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
          ),
          const SizedBox(height: 12),
          _summaryCard('Tóm tắt hôm nay', [
            _summaryRow('RMSSD', rmssdMin, rmssdAvg, rmssdMax, unit: 'ms'),
            if (pnn != null)
              _summaryRow(
                'pNN50',
                (pnn.min ?? 0),
                (pnn.avg ?? 0),
                (pnn.max ?? 0),
                unit: '%',
              ),
            if (hr != null)
              _summaryRow(
                'HR',
                (hr.min ?? 0),
                (hr.avg ?? 0),
                (hr.max ?? 0),
                unit: 'bpm',
              ),
            if (sc != null)
              _summaryRow('Score', (sc.min ?? 0), (sc.avg ?? 0), (sc.max ?? 0)),
          ], showHeaders: true),
        ],
      ),
    );
  }

  // Week: daily average Score bars + manual metrics summary
  Widget _buildWeek(HrvAggregate agg) {
    final bars = <BarChartGroupData>[
      for (int i = 0; i < 7; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: i < agg.weekScoreAvg.length
                  ? agg.weekScoreAvg[i].clamp(0, 100)
                  : 0,
              width: 12,
              borderRadius: BorderRadius.circular(2),
              color: AppColors.primaryColor,
            ),
          ],
        ),
    ];

    (double, double, double) s(List<double> v) => _summary(v);
    final pnn = s(agg.weekPnn50);
    final hr = s(agg.weekHr);
    final sc = s(agg.weekScore);
    final sd = s(agg.weekSdnn);

    return SingleChildScrollView(
      child: Column(
        children: [
          ChartContainer(
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 20,
                        getTitlesWidget: (v, m) {
                          final iv = v.round();
                          if (iv % 20 == 0 && iv >= 0 && iv <= 100) {
                            return Text(iv.toString());
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, m) {
                          final i = v.round();
                          if (i < 0 || i > 6) return const SizedBox.shrink();
                          final d = agg.weekStart.add(Duration(days: i));
                          return Text(
                            '${d.day}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: bars,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _summaryCard('Tổng kết tuần', [
            _summaryRow('pNN50', pnn.$1, pnn.$3, pnn.$2, unit: '%'),
            _summaryRow('HR', hr.$1, hr.$3, hr.$2, unit: 'bpm'),
            _summaryRow('Score', sc.$1, sc.$3, sc.$2),
            _summaryRow('SDNN', sd.$1, sd.$3, sd.$2, unit: 'ms'),
          ]),
        ],
      ),
    );
  }

  // Month: daily average Score bars + manual metrics summary
  Widget _buildMonth(HrvAggregate agg) {
    final bars = <BarChartGroupData>[
      for (int i = 0; i < agg.monthScoreAvg.length; i++)
        BarChartGroupData(
          x: i + 1,
          barRods: [
            BarChartRodData(
              toY: agg.monthScoreAvg[i].clamp(0, 100),
              width: 10,
              borderRadius: BorderRadius.circular(2),
              color: AppColors.primaryColor,
            ),
          ],
        ),
    ];

    (double, double, double) s(List<double> v) => _summary(v);
    final pnn = s(agg.monthPnn50);
    final hr = s(agg.monthHr);
    final sc = s(agg.monthScore);
    final sd = s(agg.monthSdnn);

    const ticks = {1, 7, 14, 21, 28};
    return SingleChildScrollView(
      child: Column(
        children: [
          ChartContainer(
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 20,
                        getTitlesWidget: (v, m) {
                          final iv = v.round();
                          if (iv % 20 == 0 && iv >= 0 && iv <= 100) {
                            return Text(iv.toString());
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, m) {
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
                  ),
                  barGroups: bars,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _summaryCard('Tổng kết tháng', [
            _summaryRow('pNN50', pnn.$1, pnn.$3, pnn.$2, unit: '%'),
            _summaryRow('HR', hr.$1, hr.$3, hr.$2, unit: 'bpm'),
            _summaryRow('Score', sc.$1, sc.$3, sc.$2),
            _summaryRow('SDNN', sd.$1, sd.$3, sd.$2, unit: 'ms'),
          ]),
        ],
      ),
    );
  }

  // ---- Summary helpers ----

  (double, double, double) _summary(List<double> values) {
    final xs = values.where((v) => v.isFinite && v > 0).toList();
    if (xs.isEmpty) return (0, 0, 0);
    xs.sort();
    final minV = xs.first;
    final maxV = xs.last;
    final avgV = xs.reduce((a, b) => a + b) / xs.length;
    return (minV, maxV, avgV);
  }

  Widget _summaryCard(
    String title,
    List<Widget> rows, {
    bool showHeaders = false,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (showHeaders)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(flex: 2, child: SizedBox()),
                  Expanded(
                    child: Center(
                      child: Text('Min', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Avg', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Max', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ...rows,
        ],
      ),
    );
  }

  Widget _summaryRow(
    String name,
    double min,
    double avg,
    double max, {
    String unit = '',
  }) {
    String fmt(double v) => v <= 0
        ? '-'
        : '${v.toStringAsFixed(0)}${unit.isNotEmpty ? ' $unit' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Center(child: Text(fmt(min)))),
          Expanded(child: Center(child: Text(fmt(avg)))),
          Expanded(child: Center(child: Text(fmt(max)))),
        ],
      ),
    );
  }
}
