import 'package:fl_chart/fl_chart.dart';
import 'package:health/health.dart';

class Stats {
  final double? min;
  final double? max;
  final double? avg;
  const Stats(this.min, this.max, this.avg);
}

DateTime startOfWeek(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  return d.subtract(Duration(days: d.weekday - 1)); // Monday
}

List<FlSpot> mapHealthToDaySpots(
  List<HealthDataPoint> data,
  DateTime start,
  double Function(HealthDataPoint) valueOf,
) {
  final pts = <FlSpot>[];
  for (final d in data) {
    final hours = d.dateFrom.difference(start).inMinutes / 60.0;
    if (hours < 0 || hours > 24) continue;
    final v = valueOf(d);
    if (v <= 0) continue;
    pts.add(FlSpot(hours, v));
  }
  pts.sort((a, b) => a.x.compareTo(b.x));
  return pts;
}

List<double?> hourlyAveragesFromSpots(List<FlSpot> spots, {int bins = 24}) {
  final buckets = List<List<double>>.generate(bins, (_) => []);
  for (final s in spots) {
    final i = s.x.floor();
    if (i >= 0 && i < bins) buckets[i].add(s.y);
  }
  return buckets
      .map((b) => b.isEmpty ? null : b.reduce((a, c) => a + c) / b.length)
      .toList();
}

List<double?> dailyAveragesFromHealth(
  List<HealthDataPoint> raw,
  DateTime startDay,
  int count, {
  required double Function(HealthDataPoint) valueOf,
}) {
  final buckets = List<List<double>>.generate(count, (_) => []);
  for (final d in raw) {
    final idx = d.dateFrom.difference(startDay).inDays;
    if (idx < 0 || idx >= count) continue;
    final v = valueOf(d);
    if (v <= 0) continue;
    buckets[idx].add(v);
  }
  return buckets
      .map((l) => l.isEmpty ? null : l.reduce((a, c) => a + c) / l.length)
      .toList();
}

List<double?> dailyAveragesFromFirestore<T>(
  List<T> samples,
  DateTime startDay,
  int count, {
  required DateTime Function(T) timeOf,
  required double Function(T) valueOf,
}) {
  final buckets = List<List<double>>.generate(count, (_) => []);
  for (final s in samples) {
    final idx = timeOf(s).difference(startDay).inDays;
    if (idx < 0 || idx >= count) continue;
    final v = valueOf(s);
    if (v <= 0) continue;
    buckets[idx].add(v);
  }
  return buckets
      .map((l) => l.isEmpty ? null : l.reduce((a, c) => a + c) / l.length)
      .toList();
}

Stats calcStats(Iterable<double> valuesIterable) {
  final values = valuesIterable.where((v) => v > 0).toList();
  if (values.isEmpty) return const Stats(null, null, null);
  values.sort();
  final min = values.first;
  final max = values.last;
  final avg = values.reduce((a, b) => a + b) / values.length;
  return Stats(min, max, avg);
}
