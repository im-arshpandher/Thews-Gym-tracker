import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('NotificationService initialization warning: $e');
    }
  }

  Future<void> showRestTimerNotification(int secondsRemaining) async {
    debugPrint('Rest timer notification: $secondsRemaining seconds remaining');
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'rest_timer_channel',
      'Rest Timer Alerts',
      channelDescription: 'Notifications for workout rest timer completion',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        1001,
        'Rest Complete!',
        'Your rest timer has expired. Ready for your next set!',
        details,
      );
    } catch (e) {
      debugPrint('Error showing rest timer notification: $e');
    }
  }

  Future<void> showWorkoutActiveNotification(int durationSeconds) async {
    debugPrint(
      'Active workout session notification: $durationSeconds seconds elapsed',
    );
    if (!_isInitialized) await initialize();

    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final formattedTime =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    const androidDetails = AndroidNotificationDetails(
      'active_workout_channel',
      'Active Workout Session',
      channelDescription:
          'Ongoing notification displaying active workout session duration',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        1002,
        'Workout In Progress',
        'Elapsed time: $formattedTime',
        details,
      );
    } catch (e) {
      debugPrint('Error showing active workout notification: $e');
    }
  }

  Future<void> cancelNotifications() async {
    debugPrint('Cancelled active notifications');
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error canceling notifications: $e');
    }
  }

  Future<void> cancelWorkoutNotification() async {
    try {
      await _notificationsPlugin.cancel(1002);
    } catch (e) {
      debugPrint('Error canceling workout notification: $e');
    }
  }
}
