import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class SessionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'user_sessions';

  /// Get unique device ID
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown-ios';
      }
      return 'unknown-device';
    } catch (e) {
      return 'unknown-device-error';
    }
  }

  /// Create or update session when user logs in
  static Future<void> createSession(String userId) async {
    try {
      final deviceId = await getDeviceId();
      final timestamp = FieldValue.serverTimestamp();

      print(
        '[SessionService] Creating session for user: $userId, deviceId: $deviceId',
      );

      await _firestore.collection(_collection).doc(userId).set({
        'deviceId': deviceId,
        'lastLoginAt': timestamp,
        'isActive': true,
      });

      print('[SessionService] Session created successfully');
    } catch (e) {
      print('[SessionService] Failed to create session: $e');
      throw Exception('Failed to create session: $e');
    }
  }

  /// Check if current device session is valid
  static Future<bool> isCurrentSessionValid(String userId) async {
    try {
      final deviceId = await getDeviceId();
      final doc = await _firestore.collection(_collection).doc(userId).get();

      if (!doc.exists) return false;

      final data = doc.data();
      final storedDeviceId = data?['deviceId'] as String?;
      final isActive = data?['isActive'] as bool? ?? false;

      return storedDeviceId == deviceId && isActive;
    } catch (e) {
      return false;
    }
  }

  /// Listen to session changes (for detecting login from another device)
  static Stream<bool> watchSessionValidity(String userId) async* {
    final deviceId = await getDeviceId();
    print(
      '[SessionService] Start watching session for user: $userId, currentDeviceId: $deviceId',
    );

    await for (final snapshot
        in _firestore.collection(_collection).doc(userId).snapshots()) {
      if (!snapshot.exists) {
        print('[SessionService] Session document does not exist');
        yield false;
        continue;
      }

      final data = snapshot.data();
      final storedDeviceId = data?['deviceId'] as String?;
      final isActive = data?['isActive'] as bool? ?? false;

      final isValid = storedDeviceId == deviceId && isActive;
      print(
        '[SessionService] Session update - storedDeviceId: $storedDeviceId, currentDeviceId: $deviceId, isActive: $isActive, isValid: $isValid',
      );

      // Session is valid if deviceId matches and is active
      yield isValid;
    }
  }

  /// Clear session when user logs out
  static Future<void> clearSession(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'isActive': false,
        'logoutAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore if document doesn't exist
    }
  }

  /// Delete session document
  static Future<void> deleteSession(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).delete();
    } catch (e) {
      // Ignore errors
    }
  }
}
