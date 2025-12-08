import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medication_reminder_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../providers/health_monitoring_provider.dart';

/// Service quản lý lịch nhắc thuốc
class MedicationReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications;

  MedicationReminderService(this._notifications);

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

      // Schedule notifications
      await _scheduleNotifications(reminder.copyWith(id: docRef.id));

      print('✅ Đã thêm lịch nhắc thuốc: ${reminder.medicationName}');
      return docRef.id;
    } catch (e) {
      print('❌ Lỗi thêm lịch nhắc: $e');
      rethrow;
    }
  }

  /// Cập nhật lịch nhắc
  Future<void> updateReminder(MedicationReminder reminder) async {
    try {
      await _remindersCollection
          .doc(reminder.id)
          .update(reminder.toFirestore());

      // Cancel old notifications and schedule new ones
      await _cancelNotifications(reminder);
      if (reminder.isActive) {
        await _scheduleNotifications(reminder);
      }

      print('✅ Đã cập nhật lịch nhắc thuốc: ${reminder.medicationName}');
    } catch (e) {
      print('❌ Lỗi cập nhật lịch nhắc: $e');
      rethrow;
    }
  }

  /// Bật/tắt nhắc nhở
  Future<void> toggleReminder(String reminderId, bool isActive) async {
    try {
      await _remindersCollection.doc(reminderId).update({'isActive': isActive});

      // Get reminder to manage notifications
      final doc = await _remindersCollection.doc(reminderId).get();
      final reminder = MedicationReminder.fromFirestore(doc);

      if (isActive) {
        await _scheduleNotifications(reminder);
      } else {
        await _cancelNotifications(reminder);
      }

      print(
        '✅ Đã ${isActive ? "bật" : "tắt"} nhắc nhở: ${reminder.medicationName}',
      );
    } catch (e) {
      print('❌ Lỗi toggle nhắc nhở: $e');
      rethrow;
    }
  }

  /// Xóa lịch nhắc
  Future<void> deleteReminder(String reminderId) async {
    try {
      // Get reminder to cancel notifications
      final doc = await _remindersCollection.doc(reminderId).get();
      if (doc.exists) {
        final reminder = MedicationReminder.fromFirestore(doc);
        await _cancelNotifications(reminder);
      }

      await _remindersCollection.doc(reminderId).delete();
      print('✅ Đã xóa lịch nhắc');
    } catch (e) {
      print('❌ Lỗi xóa lịch nhắc: $e');
      rethrow;
    }
  }

  /// Lên lịch thông báo cho tất cả các mốc thời gian
  Future<void> _scheduleNotifications(MedicationReminder reminder) async {
    for (final time in reminder.reminderTimes) {
      await _scheduleNotification(reminder, time);
    }
  }

  /// Lên lịch một thông báo cụ thể
  Future<void> _scheduleNotification(
    MedicationReminder reminder,
    ReminderTime time,
  ) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'medication_reminders',
        'Nhắc uống thuốc',
        channelDescription: 'Thông báo nhắc nhở uống thuốc theo lịch',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        reminder.notificationId(time),
        '💊 Nhắc uống thuốc',
        '${reminder.medicationName} - Đã đến giờ uống thuốc',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );

      print('✅ Đã lên lịch thông báo: ${reminder.medicationName} lúc $time');
    } catch (e) {
      print('❌ Lỗi lên lịch thông báo: $e');
    }
  }

  /// Hủy tất cả thông báo của một reminder
  Future<void> _cancelNotifications(MedicationReminder reminder) async {
    for (final time in reminder.reminderTimes) {
      await _notifications.cancel(reminder.notificationId(time));
    }
    print('✅ Đã hủy thông báo: ${reminder.medicationName}');
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

      print('✅ Đã xóa tất cả lịch nhắc của thuốc');
    } catch (e) {
      print('❌ Lỗi xóa lịch nhắc của thuốc: $e');
    }
  }
}

/// Provider
final medicationReminderServiceProvider = Provider<MedicationReminderService>((
  ref,
) {
  final notifications = ref.watch(localNotificationsProvider);
  return MedicationReminderService(notifications);
});
