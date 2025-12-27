import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/chest_xray_service.dart';
import '../../data/repositories/chest_xray_repository.dart';
import 'chest_xray_state.dart';

final chestXrayServiceProvider = Provider<ChestXrayService>((ref) {
  return ChestXrayService();
});

final chestXrayRepositoryProvider = Provider<ChestXrayRepository>((ref) {
  final service = ref.watch(chestXrayServiceProvider);
  return ChestXrayRepository(service);
});

final chestXrayViewModelProvider =
    StateNotifierProvider<ChestXrayViewModel, ChestXrayState>((ref) {
      final repository = ref.watch(chestXrayRepositoryProvider);
      return ChestXrayViewModel(repository);
    });

class ChestXrayViewModel extends StateNotifier<ChestXrayState> {
  final ChestXrayRepository _repository;

  ChestXrayViewModel(this._repository) : super(const ChestXrayState());

  // Update settings
  void updateConfidenceThreshold(double value) {
    state = state.copyWith(confidenceThreshold: value);
  }

  void updateOverlayTransparency(double value) {
    state = state.copyWith(overlayTransparency: value);
  }

  void updateBoxThickness(int value) {
    state = state.copyWith(boxThickness: value);
  }

  void toggleLungSegmentation(bool value) {
    state = state.copyWith(useLungSegmentation: value);
  }

  void toggleShowLungMask(bool value) {
    state = state.copyWith(showLungMask: value);
  }

  void changeImageViewMode(String mode) {
    state = state.copyWith(imageViewMode: mode);
  }

  // Pick image
  Future<Map<String, dynamic>> pickImage(File imageFile) async {
    final result = await _repository.validateImage(imageFile);

    if (result['success']) {
      state = state.copyWith(selectedImage: imageFile);
      return {
        'warning': result['warning'] ?? false,
        'message': result['message'],
      };
    } else {
      state = state.copyWith(error: result['error']);
      return {'warning': false, 'error': result['error']};
    }
  }

  // Check server health
  Future<Map<String, dynamic>> checkServerHealth() async {
    final result = await _repository.checkServerHealth();
    if (!result['success']) {
      state = state.copyWith(error: result['error']);
    }
    return result;
  }

  // Detect pneumonia
  Future<void> detectPneumonia() async {
    if (state.selectedImage == null) {
      state = state.copyWith(error: 'Vui lòng chọn ảnh X-quang');
      return;
    }

    state = state.copyWith(
      isProcessing: true,
      resultImageBase64: null,
      numDetections: 0,
      detections: [],
      error: null,
    );

    final result = await _repository.detectPneumonia(
      imageFile: state.selectedImage!,
      confidence: state.confidenceThreshold,
      useSegmentation: state.useLungSegmentation,
      showLungMask: state.showLungMask,
      overlayAlpha: state.overlayTransparency,
      boxThickness: state.boxThickness,
    );

    if (result['success']) {
      final data = result['data'];

      state = state.copyWith(
        resultImageBase64: data['result_image_base64'],
        lungMaskImageBase64: data['lung_mask_image_base64'],
        detectionImageBase64: data['detection_image_base64'],
        originalImageBase64: data['original_image'],
        numDetections: data['num_detections'],
        lungCoverage: data['lung_coverage'],
        detections: data['detections'],
        imageDimensionsInfo: data['image_dimensions'],
        imageViewMode: 'result',
        isProcessing: false,
        boxThickness: data['recommended_box_thickness'] ?? state.boxThickness,
      );
    } else {
      state = state.copyWith(isProcessing: false, error: result['error']);
    }
  }

  // Get current image base64
  String? getCurrentImageBase64() {
    switch (state.imageViewMode) {
      case 'lung_mask':
        return state.lungMaskImageBase64;
      case 'detection':
        return state.detectionImageBase64;
      case 'original':
        return state.originalImageBase64;
      case 'result':
      default:
        return state.resultImageBase64;
    }
  }

  // Get current image title
  String getCurrentImageTitle() {
    switch (state.imageViewMode) {
      case 'lung_mask':
        return 'Lung Mask';
      case 'detection':
        return 'Detection';
      case 'original':
        return 'Original';
      case 'result':
      default:
        return 'Tổng hợp';
    }
  }
}
