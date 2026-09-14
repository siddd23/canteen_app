import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../shared/services/api_service.dart';
import '../../shared/services/token_storage_service.dart';
import '../constants/api_constants.dart';
import '../routes/app_router.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _newOrdersChannel =
      AndroidNotificationChannel(
        'new_orders',
        'New orders',
        description: 'Alerts the canteen owner when a new order is placed.',
        importance: Importance.max,
        playSound: true,
      );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  bool _initialized = false;

  bool get _supportsNativePush {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized || !_supportsNativePush) return;
    _initialized = true;

    try {
      await _initializeNotificationChannel();

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      _tokenRefreshSubscription = FirebaseMessaging
          .instance
          .onTokenRefresh
          .listen(_registerTokenIfOwner);
      _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _openNotification,
      );

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _openNotification(initialMessage);
      }

      await registerCurrentDeviceToken();
    } catch (error) {
      debugPrint('Push notification initialization failed: $error');
    }
  }

  Future<void> _initializeNotificationChannel() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (_) => _openOrdersScreen(),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_newOrdersChannel);
    }
  }

  Future<void> registerCurrentDeviceToken() async {
    if (!_supportsNativePush) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerTokenIfOwner(token);
      }
    } catch (error) {
      debugPrint('Unable to register notification token: $error');
    }
  }

  Future<void> _registerTokenIfOwner(String token) async {
    final storage = TokenStorageService.instance;
    if (await storage.getRole() != 'canteen_owner' ||
        !await storage.hasSession) {
      return;
    }

    try {
      await ApiService.instance.post(
        '${ApiConstants.account}/notifications/token',
        body: {'token': token},
      );
    } catch (error) {
      debugPrint('Unable to save notification token: $error');
    }
  }

  Future<void> unregisterCurrentDeviceToken() async {
    if (!_supportsNativePush) return;

    try {
      if (await TokenStorageService.instance.getRole() != 'canteen_owner') {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await ApiService.instance.post(
        '${ApiConstants.account}/notifications/token/remove',
        body: {'token': token},
      );
    } catch (error) {
      debugPrint('Unable to remove notification token: $error');
    }
  }

  void _openNotification(RemoteMessage message) {
    if (message.data['type'] == 'new_order') {
      _openOrdersScreen();
    }
  }

  void _openOrdersScreen() {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      appRouter.go('${AppRoutes.ownerDashboard}?section=orders');
    });
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
    _initialized = false;
  }
}
