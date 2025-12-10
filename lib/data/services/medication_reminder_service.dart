import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medication_reminder_model.dart';

/// Service quản lý lịch nhắc thuốc (chỉ CRUD Firestore)
/// Local notifications được quản lý bởi ScheduledNotificationService
class MedicationReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection reference
  CollectionReference get _remindersCollection =>
      _firestore.collection('medication_reminders');

  /// Lấy danh sách nhắc nhở theo userId
  Stream<List<MedicationReminder>> getReminders(String userId) {
    return _remindersCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationReminder.fromFirestore(doc))
              .toList(),
        );
  }

  /// Lấy nhắc nhở theo medicationId
  Stream<List<MedicationReminder>> getRemindersByMedication(
    String medicationId,
  ) {
    return _remindersCollection
        .where('medicationId', isEqualTo: medicationId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationReminder.fromFirestore(doc))
              .toList(),
        );
  }

  /// Thêm lịch nhắc mới
  Future<String> addReminder(MedicationReminder reminder) async {
    try {
      final docRef = await _remindersCollection.add(reminder.toFirestore());
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Cập nhật lịch nhắc
  Future<void> updateReminder(MedicationReminder reminder) async {
    try {
      await _remindersCollection
          .doc(reminder.id)
          .update(reminder.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  /// Bật/tắt nhắc nhở
  Future<void> toggleReminder(String reminderId, bool isActive) async {
    try {
      await _remindersCollection.doc(reminderId).update({'isActive': isActive});
    } catch (e) {
      rethrow;
    }
  }

  /// Xóa lịch nhắc
  Future<void> deleteReminder(String reminderId) async {
    try {
      await _remindersCollection.doc(reminderId).delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Xóa tất cả lịch nhắc của một thuốc
  Future<void> deleteRemindersByMedication(String medicationId) async {
    try {
      final snapshot = await _remindersCollection
          .where('medicationId', isEqualTo: medicationId)
          .get();

      for (final doc in snapshot.docs) {
        await deleteReminder(doc.id);
      }
    } catch (e) {
      // Silent catch - errors already logged in deleteReminder
    }
  }
}

/// Provider
final medicationReminderServiceProvider = Provider<MedicationReminderService>((
  ref,
) {
  return MedicationReminderService();
});
