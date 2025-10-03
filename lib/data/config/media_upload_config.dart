enum MediaUploadProvider { firebaseStorage, cloudinary }

class MediaUploadConfig {
  // Change this to switch provider without touching UI code
  static const MediaUploadProvider provider = MediaUploadProvider.cloudinary;

  // Cloudinary settings (unsigned upload)
  // 1) Create a Cloudinary account (free tier)
  // 2) Create an unsigned upload preset (Settings -> Upload -> Upload presets)
  // 3) Fill in your cloud name and preset here
  static const String cloudinaryCloudName = 'dsrhvz84n';
  static const String cloudinaryUploadPreset = 'HealthCare';

  // Optional folder to organize uploads
  static const String cloudinaryFolder = 'avatars';
}
