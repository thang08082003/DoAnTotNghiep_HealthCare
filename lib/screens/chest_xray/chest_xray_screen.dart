import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../data/resources/gene/app_colors.dart';
import '../../data/services/chest_xray_service.dart';

class ChestXrayScreen extends StatefulWidget {
  const ChestXrayScreen({super.key});

  @override
  State<ChestXrayScreen> createState() => _ChestXrayScreenState();
}

class _ChestXrayScreenState extends State<ChestXrayScreen> {
  final TextEditingController _apiUrlController = TextEditingController(
    text:
        'http://10.0.2.2:5000', // Android Emulator: 10.0.2.2 = localhost của máy host
  );
  final ChestXrayService _service = ChestXrayService();

  double _confidenceThreshold = 0.15;
  double _overlayTransparency = 0.5;
  bool _useLungSegmentation = true;
  bool _showLungMask = true; // Hiển thị lung mask mặc định
  // Max size để giảm response từ server
  File? _selectedImage;
  bool _isProcessing = false;

  // Results
  String? _resultImageBase64;
  int _numDetections = 0;
  double _lungCoverage = 0.0;
  List<dynamic> _detections = [];

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _checkServer() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đang kiểm tra server...')));

    final result = await _service.checkServerHealth(_apiUrlController.text);

    if (!mounted) return;

    if (result['success']) {
      final data = result['data'];
      final unetLoaded = data['unet_loaded'] ?? false;
      final maskrcnnLoaded = data['maskrcnn_loaded'] ?? false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Server OK!\nUNet: ${unetLoaded ? "✓" : "✗"} | Mask R-CNN: ${maskrcnnLoaded ? "✓" : "✗"}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${result['error']}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _detectPneumonia() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ảnh X-quang')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _resultImageBase64 = null;
      _numDetections = 0;
      _detections = [];
    });

    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang phân tích X-quang...'),
            SizedBox(height: 8),
            Text(
              'AI đang xử lý, có thể mất 30s - 2 phút',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    final result = await _service.detectPneumonia(
      apiUrl: _apiUrlController.text,
      imageFile: _selectedImage!,
      confidence: _confidenceThreshold,
      useSegmentation: _useLungSegmentation,
      showLungMask: _showLungMask,
      overlayAlpha: _overlayTransparency,
    );

    if (!mounted) return;

    // Close processing dialog
    Navigator.of(context).pop();

    setState(() {
      _isProcessing = false;
    });

    if (result['success']) {
      final data = result['data'];
      setState(() {
        _resultImageBase64 = data['result_image_base64'];
        _numDetections = data['num_detections'] ?? 0;
        _lungCoverage = (data['lung_coverage'] ?? 0.0).toDouble();
        _detections = data['detections'] ?? [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phát hiện hoàn tất! Tìm thấy $_numDetections vùng bất thường',
          ),
          backgroundColor: _numDetections > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Show results dialog
      _showResultsDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${result['error']}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết quả phát hiện'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_resultImageBase64 != null) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            title: const Text('Kết quả X-quang'),
                          ),
                          body: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: Center(
                              child: Image.memory(
                                base64Decode(_resultImageBase64!),
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image.memory(
                    base64Decode(_resultImageBase64!),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '👆 Nhấn vào ảnh để xem phóng to',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Số vùng phát hiện: $_numDetections'),
              Text('Độ phủ phổi: ${_lungCoverage.toStringAsFixed(1)}%'),
              const SizedBox(height: 8),
              if (_detections.isNotEmpty) ...[
                const Text(
                  'Chi tiết:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ..._detections.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final det = entry.value;
                  final conf = (det['confidence'] * 100).toStringAsFixed(1);
                  return Text('  ${idx + 1}. Confidence: $conf%');
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Đọc X quang phổi'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API URL
            _buildSection(
              title: 'API URL',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _apiUrlController,
                    decoration: InputDecoration(
                      hintText: 'Nhập địa chỉ server',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildUrlChip('Emulator', 'http://10.0.2.2:5000'),
                      _buildUrlChip('Localhost', 'http://localhost:5000'),
                      _buildUrlChip('LAN', 'http://192.168.1.x:5000'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tip: Check server đang chạy trước khi detect',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Confidence Threshold
            _buildSection(
              title: 'Confidence Threshold',
              subtitle: _confidenceThreshold.toStringAsFixed(2),
              child: Slider(
                value: _confidenceThreshold,
                min: 0.05,
                max: 0.25,
                divisions: 20,
                label: _confidenceThreshold.toStringAsFixed(2),
                activeColor: AppColors.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _confidenceThreshold = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Overlay Transparency
            _buildSection(
              title: 'Overlay Transparency',
              subtitle: _overlayTransparency.toStringAsFixed(2),
              child: Slider(
                value: _overlayTransparency,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: _overlayTransparency.toStringAsFixed(2),
                activeColor: AppColors.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _overlayTransparency = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Toggles
            _buildSection(
              title: 'Cài đặt',
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Use Lung Segmentation'),
                    value: _useLungSegmentation,
                    activeColor: AppColors.primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _useLungSegmentation = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Show Lung Mask'),
                    value: _showLungMask,
                    activeColor: AppColors.primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _showLungMask = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Upload Area
            _buildSection(
              title: 'Upload Area',
              child: InkWell(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryColor.withValues(alpha: 0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 64,
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Kéo thả hoặc click để upload ảnh',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _checkServer,
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Check Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppColors.primaryColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _detectPneumonia,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _isProcessing ? 'Đang xử lý...' : 'Detect Pneumonia',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlChip(String label, String url) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _apiUrlController.text = url;
        });
      },
      backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
