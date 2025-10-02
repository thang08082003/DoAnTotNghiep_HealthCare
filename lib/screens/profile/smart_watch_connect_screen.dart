import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resources/gene/app_colors.dart';

class SmartWatchConnectScreen extends ConsumerStatefulWidget {
  const SmartWatchConnectScreen({super.key});

  @override
  ConsumerState<SmartWatchConnectScreen> createState() =>
      _SmartWatchConnectScreenState();
}

class _SmartWatchConnectScreenState
    extends ConsumerState<SmartWatchConnectScreen> {
  bool _scanning = false;
  bool _connected = false;
  String? _deviceName;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _deviceName = null;
    });
    // Placeholder: simulate scan delay
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _scanning = false;
      _deviceName = 'Smart Watch XYZ';
    });
  }

  Future<void> _connect() async {
    if (_deviceName == null) return;
    setState(() {
      _connected = false;
    });
    // Placeholder: simulate connect delay
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _connected = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kết nối thành công với Smart Watch')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết nối Smart Watch')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kết nối thiết bị đeo tay để đồng bộ dữ liệu sức khỏe.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _scanning ? null : _scan,
                  icon: const Icon(Icons.search),
                  label: Text(_scanning ? 'Đang quét...' : 'Quét thiết bị'),
                ),
                const SizedBox(width: 12),
                if (_deviceName != null)
                  ElevatedButton.icon(
                    onPressed: _connected ? null : _connect,
                    icon: const Icon(Icons.bluetooth_connected),
                    label: Text(_connected ? 'Đã kết nối' : 'Kết nối'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_deviceName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.watch, color: AppColors.primaryColor),
                        const SizedBox(width: 10),
                        Text(_deviceName!),
                      ],
                    ),
                    Icon(
                      _connected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _connected
                          ? Colors.green
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
