import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class HrvMeasureScreen extends StatefulWidget {
  final int durationSec;
  const HrvMeasureScreen({super.key, this.durationSec = 60});

  @override
  State<HrvMeasureScreen> createState() => _HrvMeasureScreenState();
}

class _HrvMeasureScreenState extends State<HrvMeasureScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _running = false;
  double _progress = 0.0;
  final List<double> _signal = [];
  final List<double> _timestamps = [];
  late final Stopwatch _sw;

  @override
  void initState() {
    super.initState();
    _sw = Stopwatch();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.low,
        imageFormatGroup: ImageFormatGroup.yuv420,
        enableAudio: false,
      );
      await ctrl.initialize();
      await ctrl.setFlashMode(FlashMode.off);
      if (!mounted) return;
      setState(() {
        _controller = ctrl;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được camera: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _start() async {
    if (_controller == null || _running) return;
    setState(() => _running = true);
    _signal.clear();
    _timestamps.clear();
    _progress = 0.0;
    _sw
      ..reset()
      ..start();
    try {
      await _controller!.setFlashMode(FlashMode.torch);
    } catch (_) {}
    await _controller!.startImageStream((image) {
      final nowSec = _sw.elapsedMilliseconds / 1000.0;
      final plane = image.planes.first; // Y plane
      final bytes = plane.bytes;
      int sum = 0;
      for (int i = 0; i < bytes.length; i += 4) {
        sum += bytes[i];
      }
      final yAvg = sum / (bytes.length / 4);
      _signal.add(yAvg);
      _timestamps.add(nowSec);
      final total = widget.durationSec.toDouble();
      final p = (nowSec / total).clamp(0.0, 1.0);
      if (mounted) setState(() => _progress = p);
      if (nowSec >= widget.durationSec) _finish();
    });
  }

  Future<void> _finish() async {
    if (!_running) return;
    _running = false;
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    try {
      await _controller?.setFlashMode(FlashMode.off);
    } catch (_) {}
    _sw.stop();
    final stats = _computeHrv(_signal, _timestamps);
    if (!mounted) return;
    Navigator.of(context).pop(stats);
  }

  Map<String, dynamic> _computeHrv(List<double> signal, List<double> t) {
    if (signal.isEmpty || signal.length != t.length) return _empty();
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
    if (peaks.length < 3) return _empty();

    final cutoff = (5.0 * fs).toInt();
    final p2 = peaks.where((i) => i >= cutoff).toList();
    if (p2.length < 3) return _empty();

    final rr = <double>[];
    for (int i = 1; i < p2.length; i++) {
      final dt = (t[p2[i]] - t[p2[i - 1]]) * 1000.0;
      rr.add(dt);
    }
    final rrFilt = rr.where((v) => v > 250.0 && v < 2000.0).toList();
    if (rrFilt.length < 2) return _empty();

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
    final pnn50 = rrFilt.length > 1 ? (above50 / (rrFilt.length - 1)) * 100.0 : double.nan;

    final mrr = rrFilt.reduce((a, b) => a + b) / rrFilt.length;
    final hr = mrr > 0 ? 60000.0 / mrr : double.nan;

    final scoreF = (0.5 * (rmssd / 100.0) + 0.3 * (sdnn / 100.0) + 0.2 * (pnn50 / 100.0)) * 100.0;
    final int score = scoreF.isNaN || scoreF < 0 ? 0 : math.min(100, scoreF.round());
    final String level = score < 50 ? 'low' : (score <= 80 ? 'medium' : 'high');

    return {
      'rmssd': rmssd,
      'sdnn': sdnn,
      'pnn50': pnn50,
      'hr': hr,
      'hrvScore': score,
      'hrvLevel': level,
    };
  }

  Map<String, dynamic> _empty() => {
        'rmssd': double.nan,
        'sdnn': double.nan,
        'pnn50': double.nan,
        'hr': double.nan,
        'hrvScore': 0,
        'hrvLevel': 'low',
      };

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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đo HRV')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(value: _running ? _progress : 0),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _running ? null : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Bắt đầu'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _running ? _finish : () => Navigator.pop(context),
                      icon: Icon(_running ? Icons.stop : Icons.close),
                      label: Text(_running ? 'Kết thúc' : 'Đóng'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Đặt ngón tay che camera và đèn flash để tín hiệu ổn định.'),
                ),
              ],
            ),
    );
  }
}
