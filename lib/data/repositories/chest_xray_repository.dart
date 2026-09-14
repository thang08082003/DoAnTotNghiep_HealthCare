import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import '../services/chest_xray_service.dart';

class ChestXrayRepository {
  static const String _apiUrl =
      'https://thangnguyendeptrainhatthegioi-xray.hf.space';

  final ChestXrayService _service;

  ChestXrayRepository(this._service);

  /// Validate image and get dimensions
  Future<Map<String, dynamic>> validateImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // Decode để kiểm tra kích thước thực tế
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final imageInfo = frame.image;

      final width = imageInfo.width;
      final height = imageInfo.height;
      final sizeKB = (bytes.length / 1024).toStringAsFixed(0);

      print('📤 Ảnh gốc: ${sizeKB}KB, Kích thước: ${width}x${height}px');

      // Return warning if image is too small
      if (width < 512 || height < 512) {
        return {
          'success': true,
          'warning': true,
          'message':
              '⚠️ Ảnh có độ phân giải thấp (${width}x${height}px).\n'
              'Nên dùng ảnh X-quang ít nhất 512x512px để kết quả tốt hơn!',
          'width': width,
          'height': height,
        };
      }

      return {
        'success': true,
        'warning': false,
        'width': width,
        'height': height,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check server health
  Future<Map<String, dynamic>> checkServerHealth() async {
    try {
      return await _service.checkServerHealth(_apiUrl);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Detect pneumonia and parse response
  Future<Map<String, dynamic>> detectPneumonia({
    required File imageFile,
    required double confidence,
    required bool useSegmentation,
    required bool showLungMask,
    required double overlayAlpha,
    required int boxThickness,
  }) async {
    try {
      final result = await _service.detectPneumonia(
        apiUrl: _apiUrl,
        imageFile: imageFile,
        confidence: confidence,
        useSegmentation: useSegmentation,
        showLungMask: showLungMask,
        overlayAlpha: overlayAlpha,
        boxThickness: boxThickness,
      );

      if (!result['success']) {
        return result;
      }

      // Parse and validate response
      final data = result['data'];
      final parsedData = await _parseDetectionResponse(data);

      return {'success': true, 'data': parsedData};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Parse detection response and extract image dimensions
  Future<Map<String, dynamic>> _parseDetectionResponse(
    Map<String, dynamic> data,
  ) async {
    final parsedData = <String, dynamic>{
      'result_image_base64':
          data['result_image_base64'] ?? data['result_image'],
      'lung_mask_image_base64':
          data['lung_mask_image_base64'] ?? data['lung_mask_image'],
      'detection_image_base64':
          data['detection_image_base64'] ?? data['detection_image'],
      'original_image': data['original_image'],
      'num_detections': data['num_detections'] ?? 0,
      'lung_coverage': (data['lung_coverage'] ?? 0.0).toDouble(),
      'detections': data['detections'] ?? [],
    };

    // Extract image dimensions
    if (data['result_image_base64'] != null) {
      final base64Str = data['result_image_base64'] as String;
      final dimensions = await _getImageDimensions(base64Str);

      if (dimensions != null) {
        parsedData['image_dimensions'] = dimensions['dimensionsText'];
        parsedData['image_width'] = dimensions['width'];
        parsedData['image_height'] = dimensions['height'];
        parsedData['recommended_box_thickness'] =
            dimensions['recommendedThickness'];
      }
    }

    return parsedData;
  }

  /// Get image dimensions from base64
  Future<Map<String, dynamic>?> _getImageDimensions(String base64Str) async {
    try {
      final base64Length = base64Str.length;
      final estimatedBytes = (base64Length * 0.75).toInt();
      final imageBytes = base64Decode(base64Str);
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final imageInfo = frame.image;

      final width = imageInfo.width;
      final height = imageInfo.height;
      final dimensions = '${width}x${height}px';

      print(
        '📥 Ảnh nhận về: ~${(estimatedBytes / 1024).toStringAsFixed(0)}KB, '
        'Kích thước: $dimensions',
      );

      // Tự động điều chỉnh box thickness nếu ảnh quá nhỏ
      int recommendedThickness = 1;
      if (width < 300 || height < 300) {
        print('⚠️ Ảnh quá nhỏ - khuyến nghị dùng box thickness = 1');
        recommendedThickness = 1;
      }

      return {
        'dimensionsText': dimensions,
        'width': width,
        'height': height,
        'recommendedThickness': recommendedThickness,
      };
    } catch (e) {
      print('❌ Lỗi decode ảnh: $e');
      return null;
    }
  }
}
