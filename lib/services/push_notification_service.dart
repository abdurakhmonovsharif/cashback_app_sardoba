import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

const _androidNotificationChannelId = 'sardoba_notifications';
const _androidNotificationChannelName = 'Sardoba Alerts';
const _androidNotificationChannelDescription =
    'App updates and promotions from Sardoba';

class PushNotificationManager {
  PushNotificationManager._();

  static final PushNotificationManager instance = PushNotificationManager._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _requestNotificationPermission();
    await _initializeLocalNotifications();
  }

  Future<void> _initializeLocalNotifications() async {
    // Use the launcher icon for notifications to avoid missing resource issues.
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    if (Platform.isAndroid) {
      final channel = AndroidNotificationChannel(
        _androidNotificationChannelId,
        _androidNotificationChannelName,
        description: _androidNotificationChannelDescription,
        importance: Importance.high,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }
    final androidDetails = AndroidNotificationDetails(
      _androidNotificationChannelId,
      _androidNotificationChannelName,
      channelDescription: _androidNotificationChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      onlyAlertOnce: false,
      icon: '@mipmap/ic_launcher',
      playSound: true,
    );
    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }
}
