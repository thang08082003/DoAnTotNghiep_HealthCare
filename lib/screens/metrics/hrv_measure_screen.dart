import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/hrv/hrv_measure_viewmodel.dart';

class HrvMeasureScreen extends ConsumerStatefulWidget {
  final int durationSec;
  final String?
  userId; // optional: target uid (e.g., clinician measuring for patient)
  const HrvMeasureScreen({super.key, this.durationSec = 60, this.userId});

  @override
  ConsumerState<HrvMeasureScreen> createState() => _HrvMeasureScreenState();
}

class _HrvMeasureScreenState extends ConsumerState<HrvMeasureScreen> {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không mở được camera: $e')));
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
      if (mounted) {
        setState(() => _progress = p);
        // keep VM progress in sync for UI observers if needed
        ref.read(hrvMeasureViewModelProvider.notifier).setProgress(p);
      }
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
    if (!mounted) return;
    // Delegate compute + save to ViewModel/Usecase
    final ok = await ref
        .read(hrvMeasureViewModelProvider.notifier)
        .measureAndSave(
          userId: widget.userId,
          signal: List<double>.from(_signal),
          timestamps: List<double>.from(_timestamps),
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu kết quả HRV')));
      Navigator.of(context).pop(true);
    } else {
      final err = ref.read(hrvMeasureViewModelProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Lưu kết quả HRV thất bại')),
      );
      Navigator.of(context).pop(false);
    }
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
                  child: LinearProgressIndicator(
                    value: _running ? _progress : 0,
                  ),
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
                      onPressed: _running
                          ? _finish
                          : () => Navigator.pop(context),
                      icon: Icon(_running ? Icons.stop : Icons.close),
                      label: Text(_running ? 'Kết thúc' : 'Đóng'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Đặt ngón tay che camera và đèn flash để tín hiệu ổn định.',
                  ),
                ),
              ],
            ),
    );
  }
}
