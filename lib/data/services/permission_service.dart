import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request all permissions needed for the app
  static Future<bool> requestAllPermissions() async {
    final permissions = [
      Permission.camera, // Video call
      Permission.microphone, // Video call
      Permission.notification, // Push notifications
      Permission.sensors, // Body sensors for health data
      Permission.activityRecognition, // Activity recognition for health data
    ];

    final statuses = await permissions.request();

    // Check if all critical permissions are granted
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final microphoneGranted =
        statuses[Permission.microphone]?.isGranted ?? false;

    // Camera and microphone are critical for video calls
    // Other permissions are optional but recommended
    return cameraGranted && microphoneGranted;
  }

  /// Check if any permission is permanently denied
  static Future<bool> hasPermissionsPermanentlyDenied() async {
    final permissions = [
      Permission.camera,
      Permission.microphone,
      Permission.notification,
      Permission.sensors,
      Permission.activityRecognition,
    ];

    for (final permission in permissions) {
      if (await permission.isPermanentlyDenied) {
        return true;
      }
    }
    return false;
  }

  /// Check if all critical permissions are granted
  static Future<bool> hasAllCriticalPermissions() async {
    final cameraGranted = await Permission.camera.isGranted;
    final microphoneGranted = await Permission.microphone.isGranted;
    return cameraGranted && microphoneGranted;
  }

  /// Get status of all permissions
  static Future<Map<Permission, PermissionStatus>>
  getAllPermissionsStatus() async {
    final permissions = [
      Permission.camera,
      Permission.microphone,
      Permission.notification,
      Permission.sensors,
      Permission.activityRecognition,
    ];

    final statuses = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      statuses[permission] = await permission.status;
    }
    return statuses;
  }
}
