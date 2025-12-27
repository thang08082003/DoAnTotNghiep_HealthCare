import 'dart:io';

class ChestXrayState {
  final double confidenceThreshold;
  final double overlayTransparency;
  final int boxThickness;
  final bool useLungSegmentation;
  final bool showLungMask;
  final File? selectedImage;
  final bool isProcessing;

  // Results
  final String? resultImageBase64;
  final String? lungMaskImageBase64;
  final String? detectionImageBase64;
  final String? originalImageBase64;
  final int numDetections;
  final double lungCoverage;
  final List<dynamic> detections;
  final String imageDimensionsInfo;

  // Image view mode: 'result', 'lung_mask', 'detection', 'original'
  final String imageViewMode;

  final String? error;

  const ChestXrayState({
    this.confidenceThreshold = 0.25,
    this.overlayTransparency = 0.5,
    this.boxThickness = 1,
    this.useLungSegmentation = true,
    this.showLungMask = true,
    this.selectedImage,
    this.isProcessing = false,
    this.resultImageBase64,
    this.lungMaskImageBase64,
    this.detectionImageBase64,
    this.originalImageBase64,
    this.numDetections = 0,
    this.lungCoverage = 0.0,
    this.detections = const [],
    this.imageDimensionsInfo = '',
    this.imageViewMode = 'result',
    this.error,
  });

  ChestXrayState copyWith({
    double? confidenceThreshold,
    double? overlayTransparency,
    int? boxThickness,
    bool? useLungSegmentation,
    bool? showLungMask,
    File? selectedImage,
    bool? isProcessing,
    String? resultImageBase64,
    String? lungMaskImageBase64,
    String? detectionImageBase64,
    String? originalImageBase64,
    int? numDetections,
    double? lungCoverage,
    List<dynamic>? detections,
    String? imageDimensionsInfo,
    String? imageViewMode,
    String? error,
  }) {
    return ChestXrayState(
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      overlayTransparency: overlayTransparency ?? this.overlayTransparency,
      boxThickness: boxThickness ?? this.boxThickness,
      useLungSegmentation: useLungSegmentation ?? this.useLungSegmentation,
      showLungMask: showLungMask ?? this.showLungMask,
      selectedImage: selectedImage ?? this.selectedImage,
      isProcessing: isProcessing ?? this.isProcessing,
      resultImageBase64: resultImageBase64 ?? this.resultImageBase64,
      lungMaskImageBase64: lungMaskImageBase64 ?? this.lungMaskImageBase64,
      detectionImageBase64: detectionImageBase64 ?? this.detectionImageBase64,
      originalImageBase64: originalImageBase64 ?? this.originalImageBase64,
      numDetections: numDetections ?? this.numDetections,
      lungCoverage: lungCoverage ?? this.lungCoverage,
      detections: detections ?? this.detections,
      imageDimensionsInfo: imageDimensionsInfo ?? this.imageDimensionsInfo,
      imageViewMode: imageViewMode ?? this.imageViewMode,
      error: error,
    );
  }
}
