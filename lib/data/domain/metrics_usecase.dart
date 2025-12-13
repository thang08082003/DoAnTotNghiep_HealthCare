import 'package:fl_chart/fl_chart.dart';

import '../../utilities/constant/utilities.dart' as mu;
import '../models/health_metric_models.dart';
import '../repositories/health_metrics_repository.dart';
import 'metrics_aggregate.dart';

/// All data read from Firestore only.
/// PassiveDrainWorker syncs Health Connect → Firestore in background.
class MetricsUsecase {
  final HealthMetricsRepository repo;
  MetricsUsecase({required this.repo});

  Future<MetricAggregate> heartRate({
    required String userId,
    DateTime? now,
  }) async {
    final tsNow = now ?? DateTime.now();
    // Day
    final dayStart = DateTime(tsNow.year, tsNow.month, tsNow.day);
    late final List<FlSpot> daySpots;
    late final mu.Stats dayStats;
    late final List<double?> dayHourly;

    // Week
    final monday = mu.startOfWeek(tsNow);
    late final List<FlSpot> weekSpots;
    late final mu.Stats weekStats;

    // Month
    final firstDay = DateTime(tsNow.year, tsNow.month, 1);
    final firstNextMonth = DateTime(tsNow.year, tsNow.month + 1, 1);
    final lastDay = firstNextMonth.subtract(const Duration(days: 1)).day;
    late final List<FlSpot> monthSpots;
    late final mu.Stats monthStats;

    // Firestore source (all data)
    final daySamples = await repo.heartRateStream(userId, from: dayStart).first;
    daySpots = _mapFsToDaySpots(daySamples, dayStart, (s) => s.bpm);
    dayStats = mu.calcStats(daySamples.map((e) => e.bpm));
    dayHourly = mu.hourlyAveragesFromSpots(daySpots);

    final weekSamples = await repo.heartRateStream(userId, from: monday).first;
    final weekDaily = mu.dailyAveragesFromFirestore<HeartRateSample>(
      weekSamples,
      monday,
      7,
      timeOf: (s) => s.ts,
      valueOf: (s) => s.bpm,
    );
    weekSpots = List<FlSpot>.generate(
      7,
      (i) => FlSpot(i.toDouble(), (weekDaily[i] ?? 0)),
    );
    weekStats = mu.calcStats(weekSamples.map((e) => e.bpm));

    final monthSamples = await repo
        .heartRateStream(userId, from: firstDay)
        .first;
    final monthDaily = mu.dailyAveragesFromFirestore<HeartRateSample>(
      monthSamples,
      firstDay,
      lastDay,
      timeOf: (s) => s.ts,
      valueOf: (s) => s.bpm,
    );
    monthSpots = List<FlSpot>.generate(
      lastDay,
      (i) => FlSpot((i + 1).toDouble(), (monthDaily[i] ?? 0)),
    );
    monthStats = mu.calcStats(monthSamples.map((e) => e.bpm));

    return MetricAggregate(
      daySpots: daySpots,
      dayHourlyAvg: dayHourly,
      day: _toAgg(dayStats),
      weekSpots: weekSpots,
      week: _toAgg(weekStats),
      monthSpots: monthSpots,
      month: _toAgg(monthStats),
    );
  }

  Future<MetricAggregate> spo2({required String userId, DateTime? now}) async {
    final tsNow = now ?? DateTime.now();
    // Day
    final dayStart = DateTime(tsNow.year, tsNow.month, tsNow.day);
    late final List<FlSpot> daySpots;
    late final mu.Stats dayStats;
    late final List<double?> dayHourly;
    // Week/Month
    final monday = mu.startOfWeek(tsNow);
    final firstDay = DateTime(tsNow.year, tsNow.month, 1);
    final firstNextMonth = DateTime(tsNow.year, tsNow.month + 1, 1);
    final lastDay = firstNextMonth.subtract(const Duration(days: 1)).day;
    late final List<FlSpot> weekSpots;
    late final mu.Stats weekStats;
    late final List<FlSpot> monthSpots;
    late final mu.Stats monthStats;

    // Firestore source (all data)
    final daySamples = await repo.spo2Stream(userId, from: dayStart).first;
    daySpots = _mapFsToDaySpots(daySamples, dayStart, (s) => s.percentage);
    dayStats = mu.calcStats(daySamples.map((e) => e.percentage));
    dayHourly = mu.hourlyAveragesFromSpots(daySpots);

    final weekSamples = await repo.spo2Stream(userId, from: monday).first;
    final weekDaily = mu.dailyAveragesFromFirestore<Spo2Sample>(
      weekSamples,
      monday,
      7,
      timeOf: (s) => s.ts,
      valueOf: (s) => s.percentage,
    );
    weekSpots = List<FlSpot>.generate(
      7,
      (i) => FlSpot(i.toDouble(), (weekDaily[i] ?? 0)),
    );
    weekStats = mu.calcStats(weekSamples.map((e) => e.percentage));

    final monthSamples = await repo.spo2Stream(userId, from: firstDay).first;
    final monthDaily = mu.dailyAveragesFromFirestore<Spo2Sample>(
      monthSamples,
      firstDay,
      lastDay,
      timeOf: (s) => s.ts,
      valueOf: (s) => s.percentage,
    );
    monthSpots = List<FlSpot>.generate(
      lastDay,
      (i) => FlSpot((i + 1).toDouble(), (monthDaily[i] ?? 0)),
    );
    monthStats = mu.calcStats(monthSamples.map((e) => e.percentage));

    return MetricAggregate(
      daySpots: daySpots,
      dayHourlyAvg: dayHourly,
      day: _toAgg(dayStats),
      weekSpots: weekSpots,
      week: _toAgg(weekStats),
      monthSpots: monthSpots,
      month: _toAgg(monthStats),
    );
  }

  // Helpers
  StatsAgg _toAgg(mu.Stats s) => StatsAgg(min: s.min, max: s.max, avg: s.avg);

  List<FlSpot> _mapFsToDaySpots<T>(
    List<T> samples,
    DateTime start,
    double Function(T) valueOf,
  ) {
    final pts = <FlSpot>[];
    for (final s in samples) {
      final v = valueOf(s);
      if (v <= 0) continue;
      final ts = (s is HeartRateSample)
          ? s.ts
          : (s is Spo2Sample)
          ? s.ts
          : DateTime.fromMillisecondsSinceEpoch(0);
      final hours = ts.difference(start).inMinutes / 60.0;
      if (hours >= 0 && hours <= 24) pts.add(FlSpot(hours, v));
    }
    pts.sort((a, b) => a.x.compareTo(b.x));
    return pts;
  }

  // Sleep aggregate: day totals, week/month daily totals and bedtime hours
  Future<SleepAggregate> sleep({required String userId, DateTime? now}) async {
    final tsNow = now ?? DateTime.now();
    final dayStart = DateTime(tsNow.year, tsNow.month, tsNow.day);
    final monday = mu.startOfWeek(tsNow);
    final sunday = monday.add(const Duration(days: 7));
    final firstDay = DateTime(tsNow.year, tsNow.month, 1);
    final firstNextMonth = DateTime(tsNow.year, tsNow.month + 1, 1);

    late final StageTotalsAgg dayTotals;
    late final List<StageDailyAgg> weekDaily;
    late final List<StageDailyAgg> monthDaily;
    late final List<double?> weekBedtime;
    late final List<double?> monthBedtime;

    // Fetch sessions (now contains embedded stages)
    final daySessions = await repo.sleepStream(userId, from: dayStart).first;
    final dedupedDaySessions = _dedupeOverlappingSessions(daySessions);
    dayTotals = _sumSleepStagesFromSessions(dedupedDaySessions, dayStart, tsNow);

    final weekSessions = await repo.sleepStream(userId, from: monday).first;
    final dedupedWeekSessions = _dedupeOverlappingSessions(weekSessions);
    weekDaily = _dailyFromSessions(dedupedWeekSessions, monday, sunday);
    weekBedtime = _bedtimeFromFs(dedupedWeekSessions, monday, sunday);

    final monthSessions = await repo.sleepStream(userId, from: firstDay).first;
    final dedupedMonthSessions = _dedupeOverlappingSessions(monthSessions);
    monthDaily = _dailyFromSessions(dedupedMonthSessions, firstDay, firstNextMonth);
    monthBedtime = _bedtimeFromFs(dedupedMonthSessions, firstDay, firstNextMonth);

    return SleepAggregate(
      dayTotals: dayTotals,
      weekDaily: weekDaily,
      weekBedtimeHours: weekBedtime,
      monthDaily: monthDaily,
      monthBedtimeHours: monthBedtime,
    );
  }

  // HRV aggregate (Firestore-backed)
  Future<HrvAggregate> hrv({required String userId, DateTime? now}) async {
    final tsNow = now ?? DateTime.now();
    final dayStart = DateTime(tsNow.year, tsNow.month, tsNow.day);
    final weekStart = mu.startOfWeek(tsNow);
    // final weekEnd = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(tsNow.year, tsNow.month, 1);
    final monthEnd = DateTime(tsNow.year, tsNow.month + 1, 1);

    // Day: hourly score averages and RMSSD stats + day pNN50/HR/Score stats
    final dayDocs = await repo.hrvStream(userId, from: dayStart).first;
    final dayBuckets = List<List<double>>.generate(24, (_) => []);
    final dayRmssdVals = <double>[];
    final dayPnn50Vals = <double>[];
    final dayHrVals = <double>[];
    final daySdnnVals = <double>[];
    final dayScoreVals = <double>[];
    for (final s in dayDocs) {
      final hour = s.ts.difference(dayStart).inHours;
      final score = s.score?.toDouble();
      if (hour >= 0 &&
          hour < 24 &&
          score != null &&
          score.isFinite &&
          score >= 0) {
        dayBuckets[hour].add(score);
      }
      final rm = s.rmssd;
      if (rm != null && rm.isFinite && rm > 0) dayRmssdVals.add(rm);
      if (s.pnn50 != null && s.pnn50!.isFinite) dayPnn50Vals.add(s.pnn50!);
      if (s.hr != null && s.hr!.isFinite) dayHrVals.add(s.hr!);
      if (s.sdnn != null && s.sdnn!.isFinite) daySdnnVals.add(s.sdnn!);
      if (s.score != null) dayScoreVals.add(s.score!.toDouble());
    }
    final dayHourlyScore = [
      for (final b in dayBuckets)
        b.isEmpty ? 0.0 : (b.reduce((a, c) => a + c) / b.length),
    ];
    final dayRmssd = mu.calcStats(dayRmssdVals);
    final dayPnn50 = mu.calcStats(dayPnn50Vals);
    final dayHr = mu.calcStats(dayHrVals);
    final daySdnn = mu.calcStats(daySdnnVals);
    final dayScore = mu.calcStats(dayScoreVals);

    // Week: daily avg score and metric collections
    final weekDocs = await repo.hrvStream(userId, from: weekStart).first;
    final wDays = 7;
    final wSum = List<double>.filled(wDays, 0);
    final wCnt = List<int>.filled(wDays, 0);
    final weekRmssd = <double>[];
    final weekPnn50 = <double>[];
    final weekHr = <double>[];
    final weekScore = <double>[];
    final weekSdnn = <double>[];
    for (final s in weekDocs) {
      final idx = s.ts.difference(weekStart).inDays;
      final sc = s.score?.toDouble();
      if (idx >= 0 && idx < wDays && sc != null && sc.isFinite && sc >= 0) {
        wSum[idx] += sc;
        wCnt[idx] += 1;
      }
      if (s.rmssd != null && s.rmssd!.isFinite) weekRmssd.add(s.rmssd!);
      if (s.pnn50 != null && s.pnn50!.isFinite) weekPnn50.add(s.pnn50!);
      if (s.hr != null && s.hr!.isFinite) weekHr.add(s.hr!);
      if (s.score != null) weekScore.add(s.score!.toDouble());
      if (s.sdnn != null && s.sdnn!.isFinite) weekSdnn.add(s.sdnn!);
    }
    final List<double> weekScoreAvg = [
      for (int i = 0; i < wDays; i++) wCnt[i] == 0 ? 0.0 : (wSum[i] / wCnt[i]),
    ];

    // Month: daily avg score and metric collections
    final monthDocs = await repo.hrvStream(userId, from: monthStart).first;
    final mDays = monthEnd.difference(monthStart).inDays;
    final mSum = List<double>.filled(mDays, 0);
    final mCnt = List<int>.filled(mDays, 0);
    final monthRmssd = <double>[];
    final monthPnn50 = <double>[];
    final monthHr = <double>[];
    final monthScore = <double>[];
    final monthSdnn = <double>[];
    for (final s in monthDocs) {
      final idx = s.ts.difference(monthStart).inDays;
      final sc = s.score?.toDouble();
      if (idx >= 0 && idx < mDays && sc != null && sc.isFinite && sc >= 0) {
        mSum[idx] += sc;
        mCnt[idx] += 1;
      }
      if (s.rmssd != null && s.rmssd!.isFinite) monthRmssd.add(s.rmssd!);
      if (s.pnn50 != null && s.pnn50!.isFinite) monthPnn50.add(s.pnn50!);
      if (s.hr != null && s.hr!.isFinite) monthHr.add(s.hr!);
      if (s.score != null) monthScore.add(s.score!.toDouble());
      if (s.sdnn != null && s.sdnn!.isFinite) monthSdnn.add(s.sdnn!);
    }
    final List<double> monthScoreAvg = [
      for (int i = 0; i < mDays; i++) mCnt[i] == 0 ? 0.0 : (mSum[i] / mCnt[i]),
    ];

    return HrvAggregate(
      dayHourlyScore: dayHourlyScore,
      dayRmssd: _toAgg(dayRmssd),
      dayPnn50: _toAgg(dayPnn50),
      dayHr: _toAgg(dayHr),
      daySdnn: _toAgg(daySdnn),
      dayScore: _toAgg(dayScore),
      weekScoreAvg: weekScoreAvg,
      monthScoreAvg: monthScoreAvg,
      weekStart: weekStart,
      weekRmssd: weekRmssd,
      weekPnn50: weekPnn50,
      weekHr: weekHr,
      weekScore: weekScore,
      weekSdnn: weekSdnn,
      monthRmssd: monthRmssd,
      monthPnn50: monthPnn50,
      monthHr: monthHr,
      monthScore: monthScore,
      monthSdnn: monthSdnn,
    );
  }

  // ----- Sleep helpers (Firestore) -----

  // Remove overlapping sleep sessions (keep the longest one for each overlap)
  List<SleepSession> _dedupeOverlappingSessions(List<SleepSession> sessions) {
    if (sessions.isEmpty) return sessions;
    
    // Sort by start time
    final sorted = List<SleepSession>.from(sessions)
      ..sort((a, b) => a.start.compareTo(b.start));
    
    final result = <SleepSession>[];
    SleepSession? current;
    
    for (final session in sorted) {
      if (current == null) {
        current = session;
        continue;
      }
      
      // Check if sessions overlap
      if (session.start.isBefore(current.end)) {
        // Overlap detected - keep the longer session
        final currentDuration = current.end.difference(current.start);
        final sessionDuration = session.end.difference(session.start);
        
        if (sessionDuration > currentDuration) {
          current = session; // Replace with longer session
        }
        // else keep current (it's longer or equal)
      } else {
        // No overlap - add current to result and move to next
        result.add(current);
        current = session;
      }
    }
    
    // Add the last session
    if (current != null) {
      result.add(current);
    }
    
    return result;
  }

  // Calculate stage totals from sessions (stages embedded in session)
  StageTotalsAgg _sumSleepStagesFromSessions(
    List<SleepSession> sessions,
    DateTime start,
    DateTime end,
  ) {
    int light = 0, deep = 0, rem = 0;

    for (final session in sessions) {
      if (session.stages != null && session.stages!.isNotEmpty) {
        // New format: has embedded stages
        for (final stage in session.stages!) {
          DateTime from = stage.start.isBefore(start) ? start : stage.start;
          DateTime to = stage.end.isAfter(end) ? end : stage.end;
          if (!to.isAfter(from)) continue;
          final mins = to.difference(from).inMinutes;

          switch (stage.stage.toLowerCase()) {
            case 'light':
              light += mins;
              break;
            case 'deep':
              deep += mins;
              break;
            case 'rem':
              rem += mins;
              break;
            case 'sleeping':
              light += mins;
              break;
            default:
              break;
          }
        }
      } else {
        // Legacy format: no stages, assign all to light
        DateTime from = session.start.isBefore(start) ? start : session.start;
        DateTime to = session.end.isAfter(end) ? end : session.end;
        if (!to.isAfter(from)) continue;
        final mins = to.difference(from).inMinutes;
        light += mins;
      }
    }

    return StageTotalsAgg(light: light, deep: deep, rem: rem);
  }

  // Calculate daily aggregates from sessions (stages embedded)
  List<StageDailyAgg> _dailyFromSessions(
    List<SleepSession> sessions,
    DateTime start,
    DateTime end,
  ) {
    final days = end.difference(start).inDays;
    final lightMins = List<int>.filled(days, 0);
    final deepMins = List<int>.filled(days, 0);
    final remMins = List<int>.filled(days, 0);

    for (final session in sessions) {
      if (session.stages != null && session.stages!.isNotEmpty) {
        // New format: process embedded stages
        for (final stage in session.stages!) {
          DateTime from = stage.start.isBefore(start) ? start : stage.start;
          DateTime to = stage.end.isAfter(end) ? end : stage.end;
          if (!to.isAfter(from)) continue;

          // Split stage across days if it spans midnight
          while (from.isBefore(to)) {
            final idx = from.difference(start).inDays;
            final nextDay = DateTime(
              from.year,
              from.month,
              from.day,
            ).add(const Duration(days: 1));
            final segEnd = to.isBefore(nextDay) ? to : nextDay;
            final mins = segEnd.difference(from).inMinutes;

            if (idx >= 0 && idx < days) {
              switch (stage.stage.toLowerCase()) {
                case 'light':
                case 'sleeping':
                  lightMins[idx] += mins;
                  break;
                case 'deep':
                  deepMins[idx] += mins;
                  break;
                case 'rem':
                  remMins[idx] += mins;
                  break;
              }
            }
            from = segEnd;
          }
        }
      } else {
        // Legacy format: no stages, assign to light
        DateTime from = session.start.isBefore(start) ? start : session.start;
        DateTime to = session.end.isAfter(end) ? end : session.end;
        if (!to.isAfter(from)) continue;

        while (from.isBefore(to)) {
          final idx = from.difference(start).inDays;
          final nextDay = DateTime(
            from.year,
            from.month,
            from.day,
          ).add(const Duration(days: 1));
          final segEnd = to.isBefore(nextDay) ? to : nextDay;
          final mins = segEnd.difference(from).inMinutes;
          if (idx >= 0 && idx < days) lightMins[idx] += mins;
          from = segEnd;
        }
      }
    }

    final out = <StageDailyAgg>[];
    for (int i = 0; i < days; i++) {
      final t = StageTotalsAgg(
        light: lightMins[i],
        deep: deepMins[i],
        rem: remMins[i],
      );
      final total = t.totalMinutes;
      final pct = total == 0
          ? const StagePctAgg.zero()
          : StagePctAgg(
              light: (lightMins[i] / total) * 100.0,
              deep: (deepMins[i] / total) * 100.0,
              rem: (remMins[i] / total) * 100.0,
            );
      out.add(StageDailyAgg(totals: t, percentages: pct));
    }
    return out;
  }

  List<double?> _bedtimeFromFs(
    List<SleepSession> sessions,
    DateTime start,
    DateTime end,
  ) {
    final days = end.difference(start).inDays;
    final out = List<double?>.filled(days, null);
    for (int i = 0; i < days; i++) {
      final dayStart = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: i));
      final windowStart = dayStart.subtract(const Duration(hours: 6));
      final windowEnd = dayStart.add(const Duration(hours: 12));
      DateTime? earliest;
      for (final s in sessions) {
        if (s.start.isAfter(windowStart) && s.start.isBefore(windowEnd)) {
          if (earliest == null || s.start.isBefore(earliest)) {
            earliest = s.start;
          }
        }
      }
      if (earliest != null) out[i] = earliest.hour + earliest.minute / 60.0;
    }
    return out;
  }
}
