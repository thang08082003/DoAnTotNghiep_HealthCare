import 'package:fl_chart/fl_chart.dart';

class StatsAgg {
  final double? min;
  final double? max;
  final double? avg;
  const StatsAgg({this.min, this.max, this.avg});
}

class MetricAggregate {
  final List<FlSpot> daySpots;
  final List<double?> dayHourlyAvg;
  final StatsAgg day;

  final List<FlSpot> weekSpots; // index-based 0..6
  final StatsAgg week;

  final List<FlSpot> monthSpots; // x=day(1..last)
  final StatsAgg month;

  const MetricAggregate({
    required this.daySpots,
    required this.dayHourlyAvg,
    required this.day,
    required this.weekSpots,
    required this.week,
    required this.monthSpots,
    required this.month,
  });
}

class StageTotalsAgg {
  final int light;
  final int deep;
  final int rem;
  const StageTotalsAgg({
    required this.light,
    required this.deep,
    required this.rem,
  });
  int get totalMinutes => light + deep + rem;
}

class StagePctAgg {
  final double light;
  final double deep;
  final double rem;
  const StagePctAgg({
    required this.light,
    required this.deep,
    required this.rem,
  });
  const StagePctAgg.zero() : light = 0, deep = 0, rem = 0;
}

class StageDailyAgg {
  final StageTotalsAgg totals;
  final StagePctAgg percentages;
  const StageDailyAgg({required this.totals, required this.percentages});
  int get totalMinutes => totals.totalMinutes;
}

class SleepAggregate {
  // Day
  final StageTotalsAgg dayTotals;
  // Week
  final List<StageDailyAgg> weekDaily; // len 7
  final List<double?> weekBedtimeHours; // len 7, 0..24
  // Month
  final List<StageDailyAgg> monthDaily; // len daysInMonth
  final List<double?> monthBedtimeHours;

  const SleepAggregate({
    required this.dayTotals,
    required this.weekDaily,
    required this.weekBedtimeHours,
    required this.monthDaily,
    required this.monthBedtimeHours,
  });
}

class HrvAggregate {
  final List<double> dayHourlyScore; // 24 values, 0..100
  final StatsAgg dayRmssd; // RMSSD stats for day
  final StatsAgg? dayPnn50; // optional: pNN50 stats for day
  final StatsAgg? dayHr; // optional: HR stats for day
  final StatsAgg? dayScore; // optional: Score stats for day

  final List<double> weekScoreAvg; // len 7
  final List<double> monthScoreAvg; // len days in month
  final DateTime weekStart; // Monday

  // Manual metrics collections for summaries
  final List<double> weekPnn50;
  final List<double> weekHr;
  final List<double> weekScore;
  final List<double> weekSdnn;

  final List<double> monthPnn50;
  final List<double> monthHr;
  final List<double> monthScore;
  final List<double> monthSdnn;

  const HrvAggregate({
    required this.dayHourlyScore,
    required this.dayRmssd,
    this.dayPnn50,
    this.dayHr,
    this.dayScore,
    required this.weekScoreAvg,
    required this.monthScoreAvg,
    required this.weekStart,
    required this.weekPnn50,
    required this.weekHr,
    required this.weekScore,
    required this.weekSdnn,
    required this.monthPnn50,
    required this.monthHr,
    required this.monthScore,
    required this.monthSdnn,
  });
}
