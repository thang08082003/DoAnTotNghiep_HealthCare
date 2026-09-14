import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../config/media_upload_config.dart';
import '../services/media_upload_service.dart';
import '../services/user_service.dart';

class AvatarRepository {
  final UserService _userService = UserService();

  Future<String> uploadAvatarAndSave({
    required String uid,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    String url;
    final ext = fileExt.toLowerCase();
    final normalizedExt = (ext == 'jpg')
        ? 'jpeg'
        : (ext == 'jpeg' || ext == 'png')
        ? ext
        : 'jpeg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'avatars/$uid/profile_$timestamp.$normalizedExt';

    if (MediaUploadConfig.provider == MediaUploadProvider.firebaseStorage) {
      final ref = FirebaseStorage.instance.ref().child(path);
      final metadata = SettableMetadata(
        contentType: normalizedExt == 'png' ? 'image/png' : 'image/jpeg',
        cacheControl: 'public, max-age=0, no-cache',
      );
      await ref.putData(bytes, metadata);
      url = await ref.getDownloadURL();
    } else {
      url = await MediaUploadService.uploadAvatar(
        uid: uid,
        data: bytes,
        fileExt: normalizedExt,
      );
    }

    await _userService.updateUserAvatar(uid, url);
    return url;
  }
}
