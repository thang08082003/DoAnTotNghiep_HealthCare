import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/sleep/sleep_viewmodel.dart';
import '../../data/domain/metrics_aggregate.dart';
import '../../components/chart/chart_container.dart';
import '../../components/metrics/metrics_segmented.dart';

class SleepDetailScreen extends ConsumerStatefulWidget {
  final String? userId; // nếu có userId -> lấy Firestore (role bác sĩ)
  const SleepDetailScreen({super.key, this.userId});

  @override
  ConsumerState<SleepDetailScreen> createState() => _SleepDetailScreenState();
}

enum _SleepRange { day, week, month }

class _SleepDetailScreenState extends ConsumerState<SleepDetailScreen>
    with WidgetsBindingObserver {
  // UI state
  _SleepRange _mode = _SleepRange.day;

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
      // trigger a refresh by invalidating viewmodel
      ref.read(sleepViewModelProvider(widget.userId).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAgg = ref.watch(sleepViewModelProvider(widget.userId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giấc ngủ'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () {
              ref
                  .read(sleepViewModelProvider(widget.userId).notifier)
                  .refresh();
            },
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
      value: _mode == _SleepRange.day
          ? MetricsRange.day
          : _mode == _SleepRange.week
          ? MetricsRange.week
          : MetricsRange.month,
      onChanged: (r) => setState(() {
        _mode = r == MetricsRange.day
            ? _SleepRange.day
            : r == MetricsRange.week
            ? _SleepRange.week
            : _SleepRange.month;
      }),
    );
  }

  Widget _buildBody(SleepAggregate agg) {
    switch (_mode) {
      case _SleepRange.day:
        return _buildDayPie(agg);
      case _SleepRange.week:
        return _buildWeekStacked(agg);
      case _SleepRange.month:
        return _buildMonthStacked(agg);
    }
  }

  // Day: pie chart of today (Light/Deep/REM) + totals and percentages
  Widget _buildDayPie(SleepAggregate agg) {
    final light = agg.dayTotals.light;
    final deep = agg.dayTotals.deep;
    final rem = agg.dayTotals.rem;
    final total = light + deep + rem;
    final sections = <PieChartSectionData>[];
    if (total > 0) {
      final lightPct = light * 100 / total;
      final deepPct = deep * 100 / total;
      final remPct = rem * 100 / total;
      sections.addAll([
        PieChartSectionData(
          color: const Color(0xFF90CAF9),
          value: lightPct,
          title: '${lightPct.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        PieChartSectionData(
          color: const Color(0xFF80CBC4),
          value: deepPct,
          title: '${deepPct.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        PieChartSectionData(
          color: const Color(0xFFFFCC80),
          value: remPct,
          title: '${remPct.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]);
    }
    return Column(
      children: [
        ChartContainer(
          child: SizedBox(
            height: 260,
            child: PieChart(
              PieChartData(
                sections: sections.isEmpty
                    ? [
                        PieChartSectionData(
                          color: Colors.grey.shade300,
                          value: 1,
                          title: '',
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 0),
                        ),
                      ]
                    : sections,
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _legend(totalMinutes: total, light: light, deep: deep, rem: rem),
        const SizedBox(height: 12),
        Container(
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
        ),
      ],
    );
  }

  // Week: two charts — duration (hours) and sleep score (%)
  Widget _buildWeekStacked(SleepAggregate agg) {
    final groupsDur = <BarChartGroupData>[];
    final groupsScore = <BarChartGroupData>[];
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: DateTime(now.year, now.month, now.day).weekday - 1),
    );
    for (int i = 0; i < 7; i++) {
      final totalMin = agg.weekDaily.length > i
          ? agg.weekDaily[i].totalMinutes
          : 0;
      final hours = totalMin / 60.0;
      final score = _scoreFromMinutes(totalMin);
      groupsDur.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: hours,
              width: 16,
              borderRadius: BorderRadius.circular(2),
              color: const Color(0xFF90CAF9),
            ),
          ],
        ),
      );
      groupsScore.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: score,
              width: 16,
              borderRadius: BorderRadius.circular(2),
              color: AppColors.primaryColor,
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          ChartContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thời lượng ngủ (giờ)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: 10,
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 2,
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final mins = (agg.weekDaily.length > groupIndex)
                                ? agg.weekDaily[groupIndex].totalMinutes
                                : (rod.toY * 60).round();
                            final d = weekStart.add(Duration(days: groupIndex));
                            return BarTooltipItem(
                              '${_fmtDay(d)} • ${_fmtHHMMFromMinutes(mins)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                      barGroups: groupsDur,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 2,
                            reservedSize: 28,
                            getTitlesWidget: (v, m) {
                              final iv = v.round();
                              if (iv % 2 == 0 && iv >= 0 && iv <= 10) {
                                return Text('$iv');
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 20,
                            getTitlesWidget: (v, m) {
                              final i = v.round();
                              if (i < 0 || i > 6) {
                                return const SizedBox.shrink();
                              }
                              final d = weekStart.add(Duration(days: i));
                              return Text(
                                '${d.day}',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ChartContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Điểm giấc ngủ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                      ),
                      barGroups: groupsScore,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 20,
                            reservedSize: 28,
                            getTitlesWidget: (v, m) {
                              final iv = v.round();
                              if (iv % 20 == 0) return Text('$iv');
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 20,
                            getTitlesWidget: (v, m) {
                              final i = v.round();
                              if (i < 0 || i > 6) {
                                return const SizedBox.shrink();
                              }
                              final d = weekStart.add(Duration(days: i));
                              return Text(
                                '${d.day}',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ChartContainer(
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: -0.5,
                  maxX: 6.5,
                  minY: 0,
                  maxY: 24,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 6,
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      getTooltipItems: (spots) => spots.map((s) {
                        final idx = s.x.round().clamp(0, 6);
                        final d = weekStart.add(Duration(days: idx));
                        return LineTooltipItem(
                          '${_fmtDay(d)} • ${_fmtHHMMFromHourDouble(s.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 6,
                        reservedSize: 28,
                        getTitlesWidget: (v, m) {
                          final iv = v.round();
                          if (iv % 6 == 0 && iv >= 0 && iv <= 24) {
                            return Text('$iv');
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 20,
                        getTitlesWidget: (v, m) {
                          final i = v.round();
                          if (i < 0 || i > 6) return const SizedBox.shrink();
                          final d = weekStart.add(Duration(days: i));
                          return Text(
                            '${d.day}',
                            style: const TextStyle(fontSize: 10),
                          );
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
                      spots: [
                        for (int i = 0; i < 7; i++)
                          if (agg.weekBedtimeHours.length > i &&
                              agg.weekBedtimeHours[i] != null)
                            FlSpot(i.toDouble(), agg.weekBedtimeHours[i]!),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Month: two charts — duration (hours) and sleep score (%)
  Widget _buildMonthStacked(SleepAggregate agg) {
    final groupsDur = <BarChartGroupData>[];
    final groupsScore = <BarChartGroupData>[];
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    for (int i = 0; i < agg.monthDaily.length; i++) {
      final totalMin = agg.monthDaily[i].totalMinutes;
      final hours = totalMin / 60.0;
      final score = _scoreFromMinutes(totalMin);
      groupsDur.add(
        BarChartGroupData(
          x: i + 1,
          barRods: [
            BarChartRodData(
              toY: hours,
              width: 10,
              borderRadius: BorderRadius.circular(2),
              color: const Color(0xFF90CAF9),
            ),
          ],
        ),
      );
      groupsScore.add(
        BarChartGroupData(
          x: i + 1,
          barRods: [
            BarChartRodData(
              toY: score,
              width: 10,
              borderRadius: BorderRadius.circular(2),
              color: AppColors.primaryColor,
            ),
          ],
        ),
      );
    }
    final ticks = {1, 7, 14, 21, 28};
    return SingleChildScrollView(
      child: Column(
        children: [
          ChartContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thời lượng ngủ (giờ)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: 10,
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 2,
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final mins = (agg.monthDaily.length > groupIndex)
                                ? agg.monthDaily[groupIndex].totalMinutes
                                : (rod.toY * 60).round();
                            final d = DateTime(
                              now.year,
                              now.month,
                              groupIndex + 1,
                            );
                            return BarTooltipItem(
                              '${_fmtDay(d)} • ${_fmtHHMMFromMinutes(mins)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                      barGroups: groupsDur,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 2,
                            reservedSize: 28,
                            getTitlesWidget: (v, m) {
                              final iv = v.round();
                              if (iv % 2 == 0 && iv >= 0 && iv <= 10) {
                                return Text('$iv');
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
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
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ChartContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Điểm giấc ngủ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                      ),
                      barGroups: groupsScore,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 20,
                            reservedSize: 28,
                            getTitlesWidget: (v, m) {
                              final iv = v.round();
                              if (iv % 20 == 0) return Text('$iv');
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
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
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ChartContainer(
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: -0.5,
                  maxX: daysInMonth.toDouble() + 0.5,
                  minY: 0,
                  maxY: 24,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 6,
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      getTooltipItems: (spots) => spots.map((s) {
                        final day = s.x.round().clamp(1, daysInMonth);
                        return LineTooltipItem(
                          '$day • ${_fmtHHMMFromHourDouble(s.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 6,
                        reservedSize: 28,
                        getTitlesWidget: (v, m) {
                          final iv = v.round();
                          if (iv % 6 == 0 && iv >= 0 && iv <= 24) {
                            return Text('$iv');
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 20,
                        getTitlesWidget: (v, m) {
                          final d = v.round();
                          if ({1, 7, 14, 21, 28}.contains(d)) return Text('$d');
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
                      spots: [
                        for (int i = 0; i < agg.monthBedtimeHours.length; i++)
                          if (agg.monthBedtimeHours[i] != null)
                            FlSpot(
                              (i + 1).toDouble(),
                              agg.monthBedtimeHours[i]!,
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _scoreFromMinutes(int minutes) {
    final score = minutes / 480.0 * 100.0;
    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
  }

  String _fmtHHMMFromMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _fmtHHMMFromHourDouble(double hour) {
    int h = hour.floor();
    int m = ((hour - h) * 60).round();
    if (m >= 60) {
      h += 1;
      m = 0;
    }
    h = h % 24;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _fmtDay(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  Widget _legend({int? totalMinutes, int? light, int? deep, int? rem}) {
    final total = totalMinutes ?? 0;
    final l = light ?? 0, d = deep ?? 0, r = rem ?? 0;
    final sum = (light != null && deep != null && rem != null)
        ? (l + d + r)
        : null;
    String fmtMin(int m) {
      final h = m ~/ 60;
      final min = m % 60;
      if (h > 0) return '${h}h ${min}m';
      return '${min}m';
    }

    Widget chip(Color c, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      );
    }

    List<Widget> lines = [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          chip(const Color(0xFF90CAF9), 'Light'),
          chip(const Color(0xFF80CBC4), 'Deep'),
          chip(const Color(0xFFFFCC80), 'REM'),
        ],
      ),
    ];
    if (sum != null && sum > 0) {
      final lp = (l * 100 / sum).toStringAsFixed(0);
      final dp = (d * 100 / sum).toStringAsFixed(0);
      final rp = (r * 100 / sum).toStringAsFixed(0);
      lines.add(const SizedBox(height: 8));
      lines.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('Light: ${fmtMin(l)} ($lp%)'),
            Text('Deep: ${fmtMin(d)} ($dp%)'),
            Text('REM: ${fmtMin(r)} ($rp%)'),
          ],
        ),
      );
    } else if (total > 0) {
      lines.add(const SizedBox(height: 8));
      lines.add(Text('Tổng thời gian ngủ: ${fmtMin(total)}'));
    }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: lines,
      ),
    );
  }
}
