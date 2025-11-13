import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../components/chart/chart_container.dart';
import '../../components/chart/chart_with_summary.dart';
import '../../components/metrics/metrics_segmented.dart';
import '../../viewmodels/heart_rate/heart_rate_viewmodel.dart';

class HeartRateDetailScreen extends ConsumerStatefulWidget {
  final String?
  userId; // nếu có userId -> lấy từ Firestore (bác sĩ theo dõi bệnh nhân)
  const HeartRateDetailScreen({super.key, this.userId});

  @override
  ConsumerState<HeartRateDetailScreen> createState() =>
      _HeartRateDetailScreenState();
}

enum _RangeMode { day, week, month }

class _HeartRateDetailScreenState extends ConsumerState<HeartRateDetailScreen> {
  // UI mode only
  _RangeMode _mode = _RangeMode.day;

  // no data-processing methods here; ViewModel/Usecase handle all logic

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhịp tim'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => ref
                .read(heartRateViewModelProvider(widget.userId).notifier)
                .refresh(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(heartRateViewModelProvider(widget.userId));
            return state.when(
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
                  Expanded(child: _buildChartAndSummary(agg)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSegmented() {
    return MetricsSegmented(
      value: _mode == _RangeMode.day
          ? MetricsRange.day
          : _mode == _RangeMode.week
          ? MetricsRange.week
          : MetricsRange.month,
      onChanged: (r) => setState(() {
        _mode = r == MetricsRange.day
            ? _RangeMode.day
            : r == MetricsRange.week
            ? _RangeMode.week
            : _RangeMode.month;
      }),
    );
  }

  Widget _buildChartAndSummary(dynamic agg) {
    switch (_mode) {
      case _RangeMode.day:
        return ChartWithSummary(
          title: 'Tổng kết hàng ngày',
          chart: _buildDayChart(agg.dayHourlyAvg),
          min: agg.day.min,
          max: agg.day.max,
          avg: agg.day.avg,
          unit: 'bpm',
        );
      case _RangeMode.week:
        return ChartWithSummary(
          title: 'Tổng kết hàng tuần',
          chart: _buildWeekChart(agg.weekSpots),
          min: agg.week.min,
          max: agg.week.max,
          avg: agg.week.avg,
          unit: 'bpm',
        );
      case _RangeMode.month:
        return ChartWithSummary(
          title: 'Tổng kết hàng tháng',
          chart: _buildMonthChart(agg.monthSpots),
          min: agg.month.min,
          max: agg.month.max,
          avg: agg.month.avg,
          unit: 'bpm',
        );
    }
  }

  Widget _buildDayChart(List<double?> dayHourlyAvg) {
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < 24; i++) {
      final y = dayHourlyAvg.isNotEmpty ? (dayHourlyAvg[i] ?? 0.0) : 0.0;
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
    return ChartContainer(
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 190,
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
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
                  '${v.toStringAsFixed(2)} bpm\n${hour}h',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 50,
                getTitlesWidget: (v, m) {
                  const ticks = {0, 50, 100, 150, 190};
                  const eps = 1e-6;
                  final iv = v.round();
                  if ((v - iv).abs() < eps && ticks.contains(iv)) {
                    return Text(iv.toString());
                  }
                  return const SizedBox.shrink();
                },
              ),
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
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
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

  Widget _buildWeekChart(List<FlSpot> weekSpots) {
    const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final values = List<double>.generate(7, (i) {
      final spot = weekSpots.length > i ? weekSpots[i] : null;
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
    return ChartContainer(
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 190,
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                final idx = group.x.clamp(0, 6);
                final label = dayLabels[idx];
                final v = rod.toY;
                return BarTooltipItem(
                  '${v.toStringAsFixed(2)} bpm\n$label',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 50,
                getTitlesWidget: (v, m) {
                  const ticks = {0, 50, 100, 150, 190};
                  const eps = 1e-6;
                  final iv = v.round();
                  if ((v - iv).abs() < eps && ticks.contains(iv)) {
                    return Text(iv.toString());
                  }
                  return const SizedBox.shrink();
                },
              ),
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
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
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

  Widget _buildMonthChart(List<FlSpot> monthSpots) {
    // Show ticks at 1, 7, 14, 21, 28
    final dayTicks = {1, 7, 14, 21, 28};
    final groups = monthSpots
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
    return ChartContainer(
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 190,
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
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
                  '${v.toStringAsFixed(2)} bpm\nNgày $day',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 50,
                getTitlesWidget: (v, m) {
                  const ticks = {0, 50, 100, 150, 190};
                  const eps = 1e-6;
                  final iv = v.round();
                  if ((v - iv).abs() < eps && ticks.contains(iv)) {
                    return Text(iv.toString());
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final d = v.round();
                  if (dayTicks.contains(d)) {
                    return Text('$d', style: const TextStyle(fontSize: 10));
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
          ),
          barGroups: groups,
        ),
      ),
    );
  }
}
