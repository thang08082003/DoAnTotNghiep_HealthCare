import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/resources/gene/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/chart/chart_container.dart';
import '../../components/chart/chart_with_summary.dart';
import '../../components/metrics/metrics_segmented.dart';
import '../../viewmodels/spo2/spo2_viewmodel.dart';
import '../../providers/user_provider.dart';

class Spo2DetailScreen extends ConsumerStatefulWidget {
  final String?
  userId; // nếu có userId -> bác sĩ xem bệnh nhân; nếu null -> bệnh nhân tự xem
  const Spo2DetailScreen({super.key, this.userId});

  @override
  ConsumerState<Spo2DetailScreen> createState() => _Spo2DetailScreenState();
}

enum _Spo2Range { day, week, month }

class _Spo2DetailScreenState extends ConsumerState<Spo2DetailScreen> {
  _Spo2Range _mode = _Spo2Range.day;

  // no data-processing in View; ViewModel/Usecase handles logic

  @override
  Widget build(BuildContext context) {
    // If userId is not provided, fallback to current user's ID
    final effectiveUserId =
        widget.userId ?? ref.watch(currentUserProvider).value?.uid;

    // If we still don't have a user ID, show error
    if (effectiveUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('SpO₂'), centerTitle: true),
        body: const Center(child: Text('Không xác định được người dùng')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpO₂'),

        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => ref
                .read(spo2ViewModelProvider(effectiveUserId).notifier)
                .refresh(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(spo2ViewModelProvider(effectiveUserId));
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
      value: _mode == _Spo2Range.day
          ? MetricsRange.day
          : _mode == _Spo2Range.week
          ? MetricsRange.week
          : MetricsRange.month,
      onChanged: (r) => setState(() {
        _mode = r == MetricsRange.day
            ? _Spo2Range.day
            : r == MetricsRange.week
            ? _Spo2Range.week
            : _Spo2Range.month;
      }),
    );
  }

  Widget _buildChartAndSummary(dynamic agg) {
    switch (_mode) {
      case _Spo2Range.day:
        return ChartWithSummary(
          title: 'Tổng kết hàng ngày',
          chart: _buildDayChart(agg.dayHourlyAvg),
          min: agg.day.min,
          max: agg.day.max,
          avg: agg.day.avg,
          unit: '%',
        );
      case _Spo2Range.week:
        return ChartWithSummary(
          title: 'Tổng kết hàng tuần',
          chart: _buildWeekChart(agg.weekSpots),
          min: agg.week.min,
          max: agg.week.max,
          avg: agg.week.avg,
          unit: '%',
        );
      case _Spo2Range.month:
        return ChartWithSummary(
          title: 'Tổng kết hàng tháng',
          chart: _buildMonthChart(agg.monthSpots),
          min: agg.month.min,
          max: agg.month.max,
          avg: agg.month.avg,
          unit: '%',
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 20,
                getTitlesWidget: (v, m) {
                  const eps = 1e-6;
                  final iv = v.round();
                  final isInt = (v - iv).abs() < eps;
                  if (isInt && iv % 20 == 0 && iv >= 0 && iv <= 100) {
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
                const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 20,
                getTitlesWidget: (v, m) {
                  const eps = 1e-6;
                  final iv = v.round();
                  final isInt = (v - iv).abs() < eps;
                  if (isInt && iv % 20 == 0 && iv >= 0 && iv <= 100) {
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
    final ticks = {1, 7, 14, 21, 28};
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 20,
                getTitlesWidget: (v, m) {
                  const eps = 1e-6;
                  final iv = v.round();
                  final isInt = (v - iv).abs() < eps;
                  if (isInt && iv % 20 == 0 && iv >= 0 && iv <= 100) {
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
                  if (ticks.contains(d)) {
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
