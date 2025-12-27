import 'dart:math' as math;
import '../models/hrv_stats.dart';

/// Pure analyzer for HRV stats from raw brightness signal and timestamps (seconds)
class HrvAnalyzer {
  const HrvAnalyzer();

  HrvStats compute(List<double> signal, List<double> t) {
    if (signal.isEmpty || signal.length != t.length) return HrvStats.empty;

    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final x = [for (final v in signal) v - mean];

    final diffs = <double>[];
    for (int i = 1; i < t.length; i++) {
      final d = t[i] - t[i - 1];
      if (d > 0) diffs.add(d);
    }
    final fs = diffs.isNotEmpty ? 1.0 / _median(diffs) : 30.0;
    final win = math.max(3, (0.5 * fs).toInt());
    final filt = _movingAverage(x, win);
    final peaks = _detectPeaks(filt, fs);
    if (peaks.length < 3) return HrvStats.empty;

    final cutoff = (5.0 * fs).toInt();
    final p2 = peaks.where((i) => i >= cutoff).toList();
    if (p2.length < 3) return HrvStats.empty;

    final rr = <double>[];
    for (int i = 1; i < p2.length; i++) {
      final dt = (t[p2[i]] - t[p2[i - 1]]) * 1000.0; // ms
      rr.add(dt);
    }
    final rrFilt = rr.where((v) => v > 250.0 && v < 2000.0).toList();
    if (rrFilt.length < 2) return HrvStats.empty;

    final sdnn = _std(rrFilt);
    double sumSq = 0;
    for (int i = 1; i < rrFilt.length; i++) {
      final d = rrFilt[i] - rrFilt[i - 1];
      sumSq += d * d;
    }
    final rmssd = math.sqrt(sumSq / (rrFilt.length - 1));

    int above50 = 0;
    for (int i = 1; i < rrFilt.length; i++) {
      if ((rrFilt[i] - rrFilt[i - 1]).abs() > 50.0) above50++;
    }
    final pnn50 = rrFilt.length > 1
        ? (above50 / (rrFilt.length - 1)) * 100.0
        : double.nan;

    final mrr = rrFilt.reduce((a, b) => a + b) / rrFilt.length;
    final hr = mrr > 0 ? 60000.0 / mrr : double.nan;

    final scoreF =
        (0.5 * (rmssd / 100.0) + 0.3 * (sdnn / 100.0) + 0.2 * (pnn50 / 100.0)) *
        100.0;
    final int score = scoreF.isNaN || scoreF < 0
        ? 0
        : math.min(100, scoreF.round());
    final String level = score < 50 ? 'low' : (score <= 80 ? 'medium' : 'high');

    return HrvStats(
      rmssd: rmssd,
      sdnn: sdnn,
      pnn50: pnn50,
      hr: hr,
      score: score,
      level: level,
    );
  }

  List<double> _movingAverage(List<double> x, int win) {
    if (x.isEmpty || win <= 1) return x;
    final n = x.length;
    final out = List<double>.filled(n, 0);
    double sum = 0;
    int i = 0;
    while (i < win && i < n) {
      sum += x[i];
      out[i] = sum / (i + 1);
      i++;
    }
    int j = 0;
    while (i < n) {
      sum += x[i];
      sum -= x[j];
      out[i] = sum / win;
      i++;
      j++;
    }
    return out;
  }

  List<int> _detectPeaks(List<double> x, double fs) {
    if (x.length < 3) return const [];
    final xs = _normalize(x);
    final thr = _percentile(xs, 75.0);
    final refractory = math.max(1, (0.3 * fs).toInt());
    final peaks = <int>[];
    int i = 1;
    while (i < xs.length - 1) {
      if (xs[i] > thr && xs[i] > xs[i - 1] && xs[i] >= xs[i + 1]) {
        peaks.add(i);
        i += refractory;
      } else {
        i++;
      }
    }
    return peaks;
  }

  List<double> _normalize(List<double> v) {
    final minV = v.reduce(math.min);
    final maxV = v.reduce(math.max);
    final range = maxV - minV;
    if (range.abs() < 1e-9) return List<double>.filled(v.length, 0);
    return [for (final x in v) (x - minV) / range];
  }

  double _std(List<double> v) {
    if (v.length < 2) return double.nan;
    final mean = v.reduce((a, b) => a + b) / v.length;
    double sum = 0;
    for (final x in v) {
      final d = x - mean;
      sum += d * d;
    }
    return math.sqrt(sum / (v.length - 1));
  }

  double _percentile(List<double> v, double p) {
    if (v.isEmpty) return double.nan;
    if (p <= 0) return v.reduce(math.min);
    if (p >= 100) return v.reduce(math.max);
    final s = [...v]..sort();
    final k = (s.length - 1) * (p / 100.0);
    final f = k.floor();
    final c = k.ceil();
    return f == c ? s[k.toInt()] : s[f] * (c - k) + s[c] * (k - f);
  }

  double _median(List<double> v) {
    if (v.isEmpty) return double.nan;
    final s = [...v]..sort();
    final n = s.length;
    final mid = n ~/ 2;
    return n % 2 == 1 ? s[mid] : (s[mid - 1] + s[mid]) / 2.0;
  }
}
