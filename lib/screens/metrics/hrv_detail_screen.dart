import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/hrv/hrv_viewmodel.dart';
import '../../data/domain/metrics_aggregate.dart';
import '../../components/chart/chart_container.dart';
import '../../components/metrics/metrics_segmented.dart';
import '../../providers/user_provider.dart';
import 'hrv_measure_screen.dart';
// removed repository/user imports as saving now handled within HrvMeasureScreen

class HrvDetailScreen extends ConsumerStatefulWidget {
  final String?
  userId; // Nếu có userId -> bác sĩ xem bệnh nhân; nếu null -> bệnh nhân tự xem
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
      final effectiveUserId =
          widget.userId ?? ref.read(currentUserProvider).value?.uid;
      if (effectiveUserId != null) {
        ref.read(hrvViewModelProvider(effectiveUserId).notifier).refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If userId is not provided, fallback to current user's ID
    final effectiveUserId =
        widget.userId ?? ref.watch(currentUserProvider).value?.uid;

    // If we still don't have a user ID, show error
    if (effectiveUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('HRV'), centerTitle: true),
        body: const Center(child: Text('Không xác định được người dùng')),
      );
    }

    final asyncAgg = ref.watch(hrvViewModelProvider(effectiveUserId));
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
                  builder: (_) => HrvMeasureScreen(userId: effectiveUserId),
                ),
              );
              if (!mounted) return;
              if (saved == true) {
                ref
                    .read(hrvViewModelProvider(effectiveUserId).notifier)
                    .refresh();
              }
            },
          ),
          IconButton(
            onPressed: () => ref
                .read(hrvViewModelProvider(effectiveUserId).notifier)
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

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBarChart(
            bars: bars,
            bottomTitles: (v, m) {
              final tick = v.toInt();
              if (tick == 0 || tick == 6 || tick == 12 || tick == 18) {
                return Text('${tick}h', style: const TextStyle(fontSize: 10));
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 12),
          _buildSummaryCard('Tóm tắt hôm nay', [
            _summaryRow('RMSSD', agg.dayRmssd.avg, 'ms'),
            if (agg.dayPnn50 != null)
              _summaryRow('pNN50', agg.dayPnn50!.avg, '%'),
            if (agg.dayHr != null) _summaryRow('HR', agg.dayHr!.avg, 'bpm'),
            if (agg.daySdnn != null)
              _summaryRow('SDNN', agg.daySdnn!.avg, 'ms'),
            if (agg.dayScore != null) _summaryRow('Score', agg.dayScore!.avg),
          ]),
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

    double avg(List<double> values) {
      final valid = values.where((v) => v.isFinite && v > 0).toList();
      if (valid.isEmpty) return 0;
      return valid.reduce((a, b) => a + b) / valid.length;
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBarChart(
            bars: bars,
            barWidth: 12,
            bottomTitles: (v, m) {
              final i = v.round();
              if (i < 0 || i > 6) return const SizedBox.shrink();
              final d = agg.weekStart.add(Duration(days: i));
              return Text('${d.day}', style: const TextStyle(fontSize: 10));
            },
          ),
          const SizedBox(height: 12),
          _buildSummaryCard('Tổng kết tuần', [
            _summaryRow('RMSSD', avg(agg.weekRmssd), 'ms'),
            _summaryRow('pNN50', avg(agg.weekPnn50), '%'),
            _summaryRow('HR', avg(agg.weekHr), 'bpm'),
            _summaryRow('SDNN', avg(agg.weekSdnn), 'ms'),
            _summaryRow('Score', avg(agg.weekScore)),
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

    double avg(List<double> values) {
      final valid = values.where((v) => v.isFinite && v > 0).toList();
      if (valid.isEmpty) return 0;
      return valid.reduce((a, b) => a + b) / valid.length;
    }

    const ticks = {1, 7, 14, 21, 28};
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBarChart(
            bars: bars,
            barWidth: 10,
            bottomTitles: (v, m) {
              final d = v.round();
              if (ticks.contains(d)) {
                return Text('$d', style: const TextStyle(fontSize: 10));
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 12),
          _buildSummaryCard('Tổng kết tháng', [
            _summaryRow('RMSSD', avg(agg.monthRmssd), 'ms'),
            _summaryRow('pNN50', avg(agg.monthPnn50), '%'),
            _summaryRow('HR', avg(agg.monthHr), 'bpm'),
            _summaryRow('SDNN', avg(agg.monthSdnn), 'ms'),
            _summaryRow('Score', avg(agg.monthScore)),
          ]),
        ],
      ),
    );
  }

  // Reusable bar chart widget
  Widget _buildBarChart({
    required List<BarChartGroupData> bars,
    double barWidth = 8,
    required Widget Function(double, TitleMeta) bottomTitles,
  }) {
    return ChartContainer(
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
                  getTitlesWidget: bottomTitles,
                ),
              ),
            ),
            barGroups: bars,
          ),
        ),
      ),
    );
  }

  // Summary card showing average values
  Widget _buildSummaryCard(String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _summaryRow(String name, double? avg, [String unit = '']) {
    final value = avg == null || avg <= 0
        ? '-'
        : '${avg.toStringAsFixed(1)}${unit.isNotEmpty ? ' $unit' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
