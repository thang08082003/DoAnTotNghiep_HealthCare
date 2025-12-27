import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../data/resources/gene/app_colors.dart';
import '../../viewmodels/chest_xray/chest_xray_viewmodel.dart';

class ChestXrayScreen extends ConsumerStatefulWidget {
  const ChestXrayScreen({super.key});

  @override
  ConsumerState<ChestXrayScreen> createState() => _ChestXrayScreenState();
}

class _ChestXrayScreenState extends ConsumerState<ChestXrayScreen> {
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (image != null) {
      final result = await ref
          .read(chestXrayViewModelProvider.notifier)
          .pickImage(File(image.path));

      if (result['warning'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _detectPneumonia() async {
    final state = ref.read(chestXrayViewModelProvider);

    if (state.selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ảnh X-quang')),
      );
      return;
    }

    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

    await ref.read(chestXrayViewModelProvider.notifier).detectPneumonia();

    if (!mounted) return;

    // Close processing dialog
    Navigator.of(context).pop();

    final newState = ref.read(chestXrayViewModelProvider);

    if (newState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${newState.error}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (newState.resultImageBase64 != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phát hiện hoàn tất! Tìm thấy ${newState.numDetections} vùng bất thường',
          ),
          backgroundColor: newState.numDetections > 0
              ? Colors.orange
              : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      _showResultsDialog();
    }
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final state = ref.watch(chestXrayViewModelProvider);
          final viewModel = ref.read(chestXrayViewModelProvider.notifier);

          return AlertDialog(
            title: const Text('Kết quả phát hiện'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image mode selector
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (state.resultImageBase64 != null)
                        _buildImageModeChip(
                          'Tổng hợp',
                          'result',
                          setDialogState,
                        ),
                      if (state.lungMaskImageBase64 != null)
                        _buildImageModeChip(
                          'Lung Mask',
                          'lung_mask',
                          setDialogState,
                        ),
                      if (state.detectionImageBase64 != null)
                        _buildImageModeChip(
                          'Detection',
                          'detection',
                          setDialogState,
                        ),
                      if (state.originalImageBase64 != null)
                        _buildImageModeChip(
                          'Original',
                          'original',
                          setDialogState,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Image display
                  if (viewModel.getCurrentImageBase64() != null) ...[
                    GestureDetector(
                      onTap: () {
                        final imageBase64 = viewModel.getCurrentImageBase64();
                        if (imageBase64 != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                backgroundColor: Colors.black,
                                appBar: AppBar(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  title: Text(
                                    '${viewModel.getCurrentImageTitle()} - X-quang',
                                  ),
                                ),
                                body: InteractiveViewer(
                                  minScale: 0.5,
                                  maxScale: 5.0,
                                  child: Center(
                                    child: Image.memory(
                                      base64Decode(imageBase64),
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                      isAntiAlias: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 500,
                          maxWidth: double.infinity,
                        ),
                        child: Image.memory(
                          base64Decode(viewModel.getCurrentImageBase64()!),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          isAntiAlias: true,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Nhấn vào ảnh để xem phóng to - ${viewModel.getCurrentImageTitle()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Số vùng phát hiện: ${state.numDetections}'),
                  Text(
                    'Độ phủ phổi: ${state.lungCoverage.toStringAsFixed(1)}%',
                  ),
                  if (state.imageDimensionsInfo.isNotEmpty)
                    Text('Kích thước ảnh: ${state.imageDimensionsInfo}'),
                  const SizedBox(height: 8),
                  if (state.detections.isNotEmpty) ...[
                    const Text(
                      'Chi tiết:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...state.detections.asMap().entries.map((entry) {
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
          );
        },
      ),
    );
  }

  Widget _buildImageModeChip(
    String label,
    String mode,
    StateSetter setDialogState,
  ) {
    final state = ref.watch(chestXrayViewModelProvider);
    final isSelected = state.imageViewMode == mode;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : AppColors.primaryColor,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        ref.read(chestXrayViewModelProvider.notifier).changeImageViewMode(mode);
        setDialogState(() {});
      },
      selectedColor: AppColors.primaryColor,
      backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chestXrayViewModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Đọc X quang phổi'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Confidence Threshold
            _buildSection(
              title: 'Confidence Threshold',
              subtitle: state.confidenceThreshold.toStringAsFixed(2),
              child: Slider(
                value: state.confidenceThreshold,
                min: 0.05,
                max: 0.25,
                divisions: 20,
                label: state.confidenceThreshold.toStringAsFixed(2),
                activeColor: AppColors.primaryColor,
                onChanged: (value) {
                  ref
                      .read(chestXrayViewModelProvider.notifier)
                      .updateConfidenceThreshold(value);
                },
              ),
            ),

            const SizedBox(height: 16),

            // Overlay Transparency
            _buildSection(
              title: 'Overlay Transparency',
              subtitle: state.overlayTransparency.toStringAsFixed(2),
              child: Slider(
                value: state.overlayTransparency,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: state.overlayTransparency.toStringAsFixed(2),
                activeColor: AppColors.primaryColor,
                onChanged: (value) {
                  ref
                      .read(chestXrayViewModelProvider.notifier)
                      .updateOverlayTransparency(value);
                },
              ),
            ),

            const SizedBox(height: 16),

            // Box Thickness
            _buildSection(
              title: 'Detection Box Thickness',
              subtitle: '${state.boxThickness}px',
              child: Column(
                children: [
                  Slider(
                    value: state.boxThickness.toDouble(),
                    min: 1,
                    max: 3,
                    divisions: 2,
                    label: '${state.boxThickness}px',
                    activeColor: AppColors.primaryColor,
                    onChanged: (value) {
                      ref
                          .read(chestXrayViewModelProvider.notifier)
                          .updateBoxThickness(value.toInt());
                    },
                  ),
                  const Text(
                    'Đường viền detection box: 1=mảnh, 2=vừa, 3=dày',
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
                    ),
                  ),
                  child: state.selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            state.selectedImage!,
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
                            const SizedBox(height: 4),
                            const Text(
                              'Khuyến nghị: Ảnh X-quang ≥ 512x512px',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isProcessing ? null : _detectPneumonia,
                icon: state.isProcessing
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
                  state.isProcessing ? 'Đang xử lý...' : 'Detect Pneumonia',
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
      ),
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
