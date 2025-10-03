import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/media_upload_config.dart';

class MediaUploadService {
  static Future<String> uploadAvatar({
    required String uid,
    required Uint8List data,
    required String fileExt, // jpg/png
  }) async {
    switch (MediaUploadConfig.provider) {
      case MediaUploadProvider.firebaseStorage:
        throw UnsupportedError(
          'Firebase Storage not enabled in this environment',
        );
      case MediaUploadProvider.cloudinary:
        return _uploadToCloudinary(uid: uid, data: data, fileExt: fileExt);
    }
  }

  static Future<String> _uploadToCloudinary({
    required String uid,
    required Uint8List data,
    required String fileExt,
  }) async {
    final cloud = MediaUploadConfig.cloudinaryCloudName;
    final preset = MediaUploadConfig.cloudinaryUploadPreset;
    if (cloud == 'YOUR_CLOUD_NAME' || preset == 'YOUR_UNSIGNED_UPLOAD_PRESET') {
      throw StateError(
        'Please configure Cloudinary cloud name and upload preset in media_upload_config.dart',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloud/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..fields['folder'] = MediaUploadConfig.cloudinaryFolder
      ..fields['public_id'] = 'profile_$uid'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          data,
          filename: 'profile_$uid.$fileExt',
          contentType: fileExt == 'png'
              ? MediaType('image', 'png')
              : MediaType('image', 'jpeg'),
        ),
      );

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      // Prefer secure_url if present
      final url = (json['secure_url'] ?? json['url']) as String?;
      if (url == null || url.isEmpty) {
        throw StateError('Cloudinary response missing URL');
      }
      return url;
    }
    throw StateError(
      'Cloudinary upload failed: ${resp.statusCode} ${resp.body}',
    );
  }
}

// (no extra class needed; using http_parser's MediaType)
