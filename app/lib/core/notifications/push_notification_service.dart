import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService(this._localNotifications);

  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _initialized = false;
  String? _cachedToken;

  static const _androidChannel = AndroidNotificationChannel(
    'apotikflow_alerts',
    'Notifikasi ApotikFlow',
    description: 'Pembayaran, stok, dan peringatan operasional',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized || kIsWeb || !DefaultFirebaseOptions.isConfigured) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_androidChannel);
      }

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(initSettings);

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _cachedToken = await messaging.getToken();
      messaging.onTokenRefresh.listen((token) => _cachedToken = token);

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      _initialized = true;
    } catch (e) {
      debugPrint('PushNotificationService init skipped: $e');
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb || !DefaultFirebaseOptions.isConfigured) return null;
    if (!_initialized) await initialize();
    if (!_initialized) return null;
    _cachedToken ??= await FirebaseMessaging.instance.getToken();
    return _cachedToken;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final id = Random().nextInt(1 << 31);
    await _localNotifications.show(
      id,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['type'],
    );
  }

}

final flutterLocalNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(flutterLocalNotificationsProvider));
});
