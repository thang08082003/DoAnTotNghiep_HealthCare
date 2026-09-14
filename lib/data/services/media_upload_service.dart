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

  // Dedicated method for chat images so they don't overwrite avatar public_id
  static Future<String> uploadChatImage({
    required String conversationId,
    required String senderId,
    required Uint8List data,
    required String fileExt,
  }) async {
    switch (MediaUploadConfig.provider) {
      case MediaUploadProvider.firebaseStorage:
        throw UnsupportedError(
          'Firebase Storage not enabled in this environment',
        );
      case MediaUploadProvider.cloudinary:
        return _uploadChatToCloudinary(
          conversationId: conversationId,
          senderId: senderId,
          data: data,
          fileExt: fileExt,
        );
    }
  }

  // Upload chat video (e.g., mp4, webm, mov) using Cloudinary video endpoint
  static Future<String> uploadChatVideo({
    required String conversationId,
    required String senderId,
    required Uint8List data,
    required String fileExt, // mp4/webm/mov
  }) async {
    switch (MediaUploadConfig.provider) {
      case MediaUploadProvider.firebaseStorage:
        throw UnsupportedError(
          'Firebase Storage not enabled in this environment',
        );
      case MediaUploadProvider.cloudinary:
        return _uploadChatVideoToCloudinary(
          conversationId: conversationId,
          senderId: senderId,
          data: data,
          fileExt: fileExt,
        );
    }
  }

  // Upload arbitrary file (PDF, DOCX, ZIP, etc.) using Cloudinary raw endpoint
  static Future<String> uploadChatFile({
    required String conversationId,
    required String senderId,
    required Uint8List data,
    required String fileName,
    String? mimeType, // optional
  }) async {
    switch (MediaUploadConfig.provider) {
      case MediaUploadProvider.firebaseStorage:
        throw UnsupportedError(
          'Firebase Storage not enabled in this environment',
        );
      case MediaUploadProvider.cloudinary:
        return _uploadChatFileToCloudinary(
          conversationId: conversationId,
          senderId: senderId,
          data: data,
          fileName: fileName,
          mimeType: mimeType,
        );
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
    // Use a unique public_id each time to avoid CDN cache issues with overwritten assets
    final ts = DateTime.now().millisecondsSinceEpoch;
    final publicId = 'profile_${uid}_$ts';
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..fields['folder'] = MediaUploadConfig.cloudinaryFolder
      ..fields['public_id'] = publicId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          data,
          filename: '$publicId.$fileExt',
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

  static Future<String> _uploadChatToCloudinary({
    required String conversationId,
    required String senderId,
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
    final ts = DateTime.now().millisecondsSinceEpoch;
    final publicId = 'chat_${conversationId}_${senderId}_$ts';
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloud/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..fields['folder'] = MediaUploadConfig.cloudinaryChatFolder
      ..fields['public_id'] = publicId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          data,
          filename: '$publicId.$fileExt',
          contentType: fileExt == 'png'
              ? MediaType('image', 'png')
              : MediaType('image', 'jpeg'),
        ),
      );
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final url = (json['secure_url'] ?? json['url']) as String?;
      if (url == null || url.isEmpty) {
        throw StateError('Cloudinary response missing URL');
      }
      return url;
    }
    throw StateError(
      'Cloudinary chat image upload failed: ${resp.statusCode} ${resp.body}',
    );
  }

  static Future<String> _uploadChatVideoToCloudinary({
    required String conversationId,
    required String senderId,
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
    final ts = DateTime.now().millisecondsSinceEpoch;
    final publicId = 'chatv_${conversationId}_${senderId}_$ts';
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloud/video/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..fields['folder'] = MediaUploadConfig.cloudinaryChatFolder
      ..fields['public_id'] = publicId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          data,
          filename: '$publicId.$fileExt',
          contentType: MediaType('video', fileExt.toLowerCase()),
        ),
      );
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final url = (json['secure_url'] ?? json['url']) as String?;
      if (url == null || url.isEmpty) {
        throw StateError('Cloudinary response missing URL');
      }
      return url;
    }
    throw StateError(
      'Cloudinary chat video upload failed: ${resp.statusCode} ${resp.body}',
    );
  }

  static Future<String> _uploadChatFileToCloudinary({
    required String conversationId,
    required String senderId,
    required Uint8List data,
    required String fileName,
    String? mimeType,
  }) async {
    final cloud = MediaUploadConfig.cloudinaryCloudName;
    final preset = MediaUploadConfig.cloudinaryUploadPreset;
    if (cloud == 'YOUR_CLOUD_NAME' || preset == 'YOUR_UNSIGNED_UPLOAD_PRESET') {
      throw StateError(
        'Please configure Cloudinary cloud name and upload preset in media_upload_config.dart',
      );
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final publicId = 'chatf_${conversationId}_${senderId}_$ts';
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/raw/upload');
    final mediaType = () {
      try {
        if (mimeType != null && mimeType.contains('/')) {
          final parts = mimeType.split('/');
          return MediaType(parts[0], parts[1]);
        }
      } catch (_) {}
      return MediaType('application', 'octet-stream');
    }();
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..fields['folder'] = MediaUploadConfig.cloudinaryChatFolder
      ..fields['public_id'] = publicId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          data,
          filename: fileName,
          contentType: mediaType,
        ),
      );
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final url = (json['secure_url'] ?? json['url']) as String?;
      if (url == null || url.isEmpty) {
        throw StateError('Cloudinary response missing URL');
      }
      return url;
    }
    throw StateError(
      'Cloudinary chat file upload failed: ${resp.statusCode} ${resp.body}',
    );
  }
}

// (no extra class needed; using http_parser's MediaType)
