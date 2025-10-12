import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:health/health.dart';

import '../../data/resources/gene/app_colors.dart';
import '../../data/services/health_connect_service.dart';

class SleepDetailScreen extends StatefulWidget {
  const SleepDetailScreen({super.key});

  @override
  State<SleepDetailScreen> createState() => _SleepDetailScreenState();
}

enum _SleepRange { day, week, month }

class _SleepDetailScreenState extends State<SleepDetailScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  bool _fetching = false;
  _SleepRange _mode = _SleepRange.day;

  // Day totals in minutes
  int _dayLight = 0;
  int _dayDeep = 0;
  int _dayRem = 0;

  late DateTime _weekStart; // Monday of current week
  // Week daily totals and percentages
  late List<_StageDaily> _weekDaily; // length 7

  // Month daily totals and percentages
  late List<_StageDaily> _monthDaily; // length = days in month
  // Sleep habit: bedtime hour per day (0..24), null if unknown
  late List<double?> _weekBedtimeHours; // length 7
  late List<double?> _monthBedtimeHours; // length = days in month

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weekStart = _startOfWeek(DateTime.now());
    _weekDaily = List.generate(
      7,
      (_) => const _StageDaily(
        totals: _StageTotals(light: 0, deep: 0, rem: 0),
        percentages: _StagePct.zero(),
      ),
    );
    _monthDaily = const [];
    _weekBedtimeHours = List<double?>.filled(7, null);
    _monthBedtimeHours = <double?>[];
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
      final svc = GoogleFitService();
      await svc.ensureConnected();
      final now = DateTime.now();

      // Day: today 00:00 -> now
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayStages = await _getStages(svc, dayStart, now);
      _dayLight = dayStages.light;
      _dayDeep = dayStages.deep;
      _dayRem = dayStages.rem;

      // Week: Mon..Sun current week
      final mon = _startOfWeek(now);
      final nextMon = mon.add(const Duration(days: 7));
      final weekDaily = await _getDailyStages(svc, mon, nextMon);
      _weekStart = mon;
      _weekDaily = weekDaily;
      _weekBedtimeHours = await _computeBedtimeHoursForRange(svc, mon, nextMon);

      // Month: 1st .. next month 1st
      final first = DateTime(now.year, now.month, 1);
      final firstNext = DateTime(now.year, now.month + 1, 1);
      final monthDaily = await _getDailyStages(svc, first, firstNext);
      _monthDaily = monthDaily;
      _monthBedtimeHours = await _computeBedtimeHoursForRange(
        svc,
        first,
        firstNext,
      );

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _startOfWeek(DateTime now) {
    final weekday = now.weekday; // Mon=1..Sun=7
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: weekday - 1));
  }

  // Query SLEEP_LIGHT/DEEP/REM and compute totals (minutes)
  Future<_StageTotals> _getStages(
    GoogleFitService svc,
    DateTime start,
    DateTime end,
  ) async {
    // Single batched fetch for all stages, then sum locally
    final pts = await svc.getDataFast(
      types: const [
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ],
      start: start,
      end: end,
    );
    int light = 0, deep = 0, rem = 0;
    for (final p in pts) {
      final from = p.dateFrom.isBefore(start) ? start : p.dateFrom;
      final to = p.dateTo.isAfter(end) ? end : p.dateTo;
      if (!to.isAfter(from)) continue;
      final mins = to.difference(from).inMinutes;
      switch (p.type) {
        case HealthDataType.SLEEP_LIGHT:
          light += mins;
          break;
        case HealthDataType.SLEEP_DEEP:
          deep += mins;
          break;
        case HealthDataType.SLEEP_REM:
          rem += mins;
          break;
        default:
          break;
      }
    }
    return _StageTotals(light: light, deep: deep, rem: rem);
  }

  // Returns a list for each day in [start, end): totals and percentages
  Future<List<_StageDaily>> _getDailyStages(
    GoogleFitService svc,
    DateTime start,
    DateTime end,
  ) async {
    final days = end.difference(start).inDays;
    if (days <= 0) return const <_StageDaily>[];

    // Fetch once for the entire range, all stages
    final pts = await svc.getDataFast(
      types: const [
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ],
      start: start,
      end: end,
    );

    final light = List<int>.filled(days, 0);
    final deep = List<int>.filled(days, 0);
    final rem = List<int>.filled(days, 0);

    for (final p in pts) {
      // Clamp to range
      DateTime from = p.dateFrom.isBefore(start) ? start : p.dateFrom;
      DateTime to = p.dateTo.isAfter(end) ? end : p.dateTo;
      if (!to.isAfter(from)) continue;

      while (from.isBefore(to)) {
        final dayStart = DateTime(from.year, from.month, from.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final segEnd = to.isBefore(dayEnd) ? to : dayEnd;
        final minutes = segEnd.difference(from).inMinutes;
        final idx = from.difference(start).inDays;
        if (idx >= 0 && idx < days && minutes > 0) {
          switch (p.type) {
            case HealthDataType.SLEEP_LIGHT:
              light[idx] += minutes;
              break;
            case HealthDataType.SLEEP_DEEP:
              deep[idx] += minutes;
              break;
            case HealthDataType.SLEEP_REM:
              rem[idx] += minutes;
              break;
            default:
              break;
          }
        }
        from = segEnd;
      }
    }

    final out = <_StageDaily>[];
    for (int i = 0; i < days; i++) {
      final t = _StageTotals(light: light[i], deep: deep[i], rem: rem[i]);
      final total = t.totalMinutes;
      final pct = total == 0
          ? const _StagePct.zero()
          : _StagePct(
              light: t.light * 100 / total,
              deep: t.deep * 100 / total,
              rem: t.rem * 100 / total,
            );
      out.add(_StageDaily(totals: t, percentages: pct));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giấc ngủ'),
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
                  Expanded(child: _buildBody()),
                ],
              ),
      ),
    );
  }

  Widget _buildSegmented() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth / 3).clamp(0.0, double.infinity);
        return CupertinoSegmentedControl<_SleepRange>(
          groupValue: _mode,
          onValueChanged: (m) => setState(() => _mode = m),
          children: {
            _SleepRange.day: SizedBox(
              width: w,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('D'),
                ),
              ),
            ),
            _SleepRange.week: SizedBox(
              width: w,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('W'),
                ),
              ),
            ),
            _SleepRange.month: SizedBox(
              width: w,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('M'),
                ),
              ),
            ),
          },
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _SleepRange.day:
        return _buildDayPie();
      case _SleepRange.week:
        return _buildWeekStacked();
      case _SleepRange.month:
        return _buildMonthStacked();
    }
  }

  // Day: pie chart of today (Light/Deep/REM) + totals and percentages
  Widget _buildDayPie() {
    final total = _dayLight + _dayDeep + _dayRem;
    final sections = <PieChartSectionData>[];
    if (total > 0) {
      final lightPct = _dayLight * 100 / total;
      final deepPct = _dayDeep * 100 / total;
      final remPct = _dayRem * 100 / total;
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
        SizedBox(
          height: 260,
          child: sections.isEmpty
              ? const Center(child: Text('Chưa có dữ liệu hôm nay'))
              : PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _legend(
          totalMinutes: total,
          light: _dayLight,
          deep: _dayDeep,
          rem: _dayRem,
        ),
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
          child: const ExpansionTile(
            tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text('Tìm hiểu giấc ngủ'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                '• Mục tiêu 7–9 giờ mỗi đêm cho người trưởng thành.\n'
                '• Cố gắng đi ngủ vào cùng một khung giờ mỗi ngày.\n'
                '• Tránh caffeine/điện thoại trước khi ngủ 2–3 giờ.\n'
                '• Ưu tiên môi trường ngủ yên tĩnh, mát mẻ, ít ánh sáng.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Week: two charts — duration (hours) and sleep score (%)
  Widget _buildWeekStacked() {
    final groupsDur = <BarChartGroupData>[];
    final groupsScore = <BarChartGroupData>[];
    for (int i = 0; i < 7; i++) {
      final totalMin = _weekDaily.length > i ? _weekDaily[i].totalMinutes : 0;
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Thời lượng ngủ (giờ)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
                      final mins = (_weekDaily.length > groupIndex)
                          ? _weekDaily[groupIndex].totalMinutes
                          : (rod.toY * 60).round();
                      final d = _weekStart.add(Duration(days: groupIndex));
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
                        if (iv % 2 == 0 && iv >= 0 && iv <= 10)
                          return Text('$iv');
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
                        final d = _weekStart.add(Duration(days: i));
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Điểm giấc ngủ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        final d = _weekStart.add(Duration(days: i));
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Thói quen giờ đi ngủ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
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
                      final d = _weekStart.add(Duration(days: idx));
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
                        if (iv % 6 == 0 && iv >= 0 && iv <= 24)
                          return Text('$iv');
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
                        final d = _weekStart.add(Duration(days: i));
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
                        if (_weekBedtimeHours.length > i &&
                            _weekBedtimeHours[i] != null)
                          FlSpot(i.toDouble(), _weekBedtimeHours[i]!),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Month: two charts — duration (hours) and sleep score (%)
  Widget _buildMonthStacked() {
    final groupsDur = <BarChartGroupData>[];
    final groupsScore = <BarChartGroupData>[];
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    for (int i = 0; i < _monthDaily.length; i++) {
      final totalMin = _monthDaily[i].totalMinutes;
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Thời lượng ngủ (giờ)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
                      final mins = (_monthDaily.length > groupIndex)
                          ? _monthDaily[groupIndex].totalMinutes
                          : (rod.toY * 60).round();
                      final now = DateTime.now();
                      final d = DateTime(now.year, now.month, groupIndex + 1);
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
                        if (iv % 2 == 0 && iv >= 0 && iv <= 10)
                          return Text('$iv');
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
                        if (ticks.contains(d))
                          return Text(
                            '$d',
                            style: const TextStyle(fontSize: 10),
                          );
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Điểm giấc ngủ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
                        if (ticks.contains(d))
                          return Text(
                            '$d',
                            style: const TextStyle(fontSize: 10),
                          );
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Thói quen giờ đi ngủ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: daysInMonth.toDouble(),
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
                      final now = DateTime.now();
                      final maxDay = DateTime(now.year, now.month + 1, 0).day;
                      final day = s.x.round().clamp(1, maxDay);
                      final d = DateTime(now.year, now.month, day);
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
                        if (iv % 6 == 0 && iv >= 0 && iv <= 24)
                          return Text('$iv');
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
                        if (ticks.contains(d))
                          return Text(
                            '$d',
                            style: const TextStyle(fontSize: 10),
                          );
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
                      for (int i = 0; i < _monthBedtimeHours.length; i++)
                        if (_monthBedtimeHours[i] != null)
                          FlSpot((i + 1).toDouble(), _monthBedtimeHours[i]!),
                    ],
                  ),
                ],
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
            Text('Light: ${fmtMin(l)} (${lp}%)'),
            Text('Deep: ${fmtMin(d)} (${dp}%)'),
            Text('REM: ${fmtMin(r)} (${rp}%)'),
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

  // Compute bedtime hour (0..24) per day in [start, end)
  // Window per day: previous day 18:00 -> current day 12:00
  Future<List<double?>> _computeBedtimeHoursForRange(
    GoogleFitService svc,
    DateTime start,
    DateTime end,
  ) async {
    final days = end.difference(start).inDays;
    if (days <= 0) return const <double?>[];
    final out = List<double?>.filled(days, null);

    // Extend fetch window to include previous evening and potential late mornings
    final fetchStart = start.subtract(const Duration(days: 1));
    final fetchEnd = end.add(const Duration(days: 1));

    final pts = await svc.getDataFast(
      types: const [
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_SESSION,
      ],
      start: fetchStart,
      end: fetchEnd,
    );

    // Group all candidate points by day index
    for (int i = 0; i < days; i++) {
      final dayStart = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: i));
      final windowStart = dayStart.subtract(
        const Duration(hours: 6),
      ); // 18:00 previous day
      final windowEnd = dayStart.add(
        const Duration(hours: 12),
      ); // 12:00 current day

      DateTime? earliest;
      for (final p in pts) {
        // Candidate if any overlap with window and start inside window
        final ps = p.dateFrom;
        if (!ps.isBefore(windowEnd) || ps.isBefore(windowStart)) continue;
        // Not before windowEnd and not before windowStart => inside windowStart..windowEnd
        if (earliest == null || ps.isBefore(earliest)) {
          earliest = ps;
        }
      }
      if (earliest != null) {
        out[i] = earliest.hour + earliest.minute / 60.0;
      }
    }

    return out;
  }
}

class _StageTotals {
  final int light;
  final int deep;
  final int rem;
  const _StageTotals({
    required this.light,
    required this.deep,
    required this.rem,
  });
  int get totalMinutes => light + deep + rem;
}

class _StagePct {
  final double light;
  final double deep;
  final double rem;
  const _StagePct({required this.light, required this.deep, required this.rem});
  const _StagePct.zero() : light = 0, deep = 0, rem = 0;
}

class _StageDaily {
  final _StageTotals totals;
  final _StagePct percentages;
  const _StageDaily({required this.totals, required this.percentages});
  int get totalMinutes => totals.totalMinutes;
}
