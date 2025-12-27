import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChestXrayService {
  Future<Map<String, dynamic>> checkServerHealth(String apiUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$apiUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Server returned status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server: $e'};
    }
  }

  Future<Map<String, dynamic>> detectPneumonia({
    required String apiUrl,
    required File imageFile,
    required double confidence,
    required bool useSegmentation,
    required bool showLungMask,
    required double overlayAlpha,
    int boxThickness = 2,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/detect'));

      // Read file as bytes first để đảm bảo data đúng
      final imageBytes = await imageFile.readAsBytes();

      // Add image file from bytes instead of path
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: imageFile.path.split('/').last,
        ),
      );

      // Add parameters
      request.fields['confidence'] = confidence.toString();
      request.fields['use_segmentation'] = useSegmentation.toString();
      request.fields['show_lung_mask'] = showLungMask.toString();
      request.fields['overlay_alpha'] = overlayAlpha.toString();
      request.fields['return_format'] = 'json';
      request.fields['quality'] = '100'; // Chất lượng tối đa
      request.fields['box_thickness'] = boxThickness.toString();
      request.fields['preserve_size'] = 'true'; // Giữ nguyên kích thước
      request.fields['max_size'] = '4096'; // Cho phép ảnh lớn hơn

      print('📤 Sending request to $apiUrl/detect...');
      print('📦 Image size: ${imageBytes.length} bytes');

      // Use Response.fromStream instead of manual stream handling
      final response = await http.Response.fromStream(await request.send())
          .timeout(
            const Duration(minutes: 10), // Timeout rất dài cho emulator
          );

      print('✅ Server responded with status: ${response.statusCode}');
      print('📦 Response size: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        print('🔍 Parsing JSON response...');
        final data = json.decode(response.body);
        print(
          '✅ Successfully parsed JSON - ${data['num_detections']} detections',
        );
        return {'success': true, 'data': data};
      } else {
        print('❌ Error response body: ${response.body}');
        return {
          'success': false,
          'error':
              'Server returned status ${response.statusCode}: ${response.body}',
        };
      }
    } on SocketException catch (e) {
      return {
        'success': false,
        'error':
            'Network error: Cannot connect to server. Make sure server is running at $apiUrl',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'error':
            'Connection error: ${e.message}. Try checking server status first.',
      };
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'error':
            'Timeout: ${e.message ?? "Request took too long"}. AI processing may need more time or image is too large.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Unexpected error: $e'};
    }
  }

  Future<Map<String, dynamic>> getModelsInfo(String apiUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$apiUrl/models/info'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Server returned status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Cannot get models info: $e'};
    }
  }
}
