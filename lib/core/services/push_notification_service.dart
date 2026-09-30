import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../shared/services/api_service.dart';
import '../../shared/services/token_storage_service.dart';
import '../constants/api_constants.dart';
import '../routes/app_router.dart';

class PendingOrderNotification {
  const PendingOrderNotification({
    required this.orderId,
    required this.canteenId,
  });

  final String orderId;
  final String canteenId;

  String get ownerRoute {
    final parameters = <String, String>{
      'section': 'orders',
      if (canteenId.isNotEmpty) 'canteenId': canteenId,
      if (orderId.isNotEmpty) 'orderId': orderId,
    };
    return Uri(
      path: AppRoutes.ownerDashboard,
      queryParameters: parameters,
    ).toString();
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _newOrdersChannel =
      AndroidNotificationChannel(
        'new_orders_v2',
        'New orders',
        description: 'Alerts the canteen owner when a new order is placed.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('order_bell'),
      );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  bool _initialized = false;
  final Completer<void> _readyCompleter = Completer<void>();
  PendingOrderNotification? _pendingOrder;

  Future<void> get ready => _readyCompleter.future;

  PendingOrderNotification? takePendingOrder() {
    final pending = _pendingOrder;
    _pendingOrder = null;
    return pending;
  }

  bool get _supportsNativePush {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_supportsNativePush) {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      return;
    }
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

      unawaited(registerCurrentDeviceToken());
    } catch (error) {
      debugPrint('Push notification initialization failed: $error');
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> _initializeNotificationChannel() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final data = Uri.splitQueryString(response.payload ?? '');
        _openOrdersScreen(
          orderId: data['orderId'] ?? '',
          canteenId: data['canteenId'] ?? '',
        );
      },
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
      _openOrdersScreen(
        orderId: message.data['orderId']?.toString() ?? '',
        canteenId: message.data['canteenId']?.toString() ?? '',
      );
    }
  }

  void _openOrdersScreen({
    required String orderId,
    required String canteenId,
  }) {
    _pendingOrder = PendingOrderNotification(
      orderId: orderId,
      canteenId: canteenId,
    );
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      // On a cold start the splash screen must restore the owner session first.
      // It will consume the pending order and perform the navigation itself.
      if (appRouter.routeInformationProvider.value.uri.path == AppRoutes.splash) {
        return;
      }
      final pending = takePendingOrder();
      if (pending != null) appRouter.go(pending.ownerRoute);
    });
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
    _initialized = false;
  }
}
