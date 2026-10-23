import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../shared/services/api_service.dart';
import '../../shared/services/token_storage_service.dart';
import '../constants/api_constants.dart';
import '../routes/app_router.dart';

const _orderAlarmChannelId = 'urgent_order_alarm_v1';

int _orderNotificationId(String orderId) =>
    orderId.codeUnits.fold<int>(1701, (value, unit) => ((value * 31) + unit) & 0x7fffffff);

@pragma('vm:entry-point')
Future<void> showPersistentOrderAlarm(RemoteMessage message) async {
  if (message.data['type'] != 'new_order') return;
  final orderId = message.data['orderId']?.toString() ?? '';
  if (orderId.isEmpty) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  const channel = AndroidNotificationChannel(
    _orderAlarmChannelId,
    'Urgent order alarms',
    description: 'Keeps ringing until the pending order is opened and handled.',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('order_bell'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );
  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  final orderNumber = message.data['orderNumber']?.toString() ?? 'New order';
  final scheduledFor = DateTime.tryParse(
    message.data['scheduledFor']?.toString() ?? '',
  );
  final scheduledLabel = scheduledFor == null
      ? ''
      : ' scheduled for ${_notificationTime(scheduledFor)}';
  await plugin.show(
    id: _orderNotificationId(orderId),
    title: 'New BookFood order',
    body: '$orderNumber$scheduledLabel is waiting for acceptance',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _orderAlarmChannelId,
        'Urgent order alarms',
        channelDescription:
        'Keeps ringing until the pending order is handled.',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(
          'order_bell',
        ),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        additionalFlags: Int32List.fromList(const [4]),
      ),
    ),
    payload: Uri(queryParameters: {
      'orderId': orderId,
      'canteenId': message.data['canteenId']?.toString() ?? '',
    }).query,
  );
}

String _notificationTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month}/${local.year} at $hour:$minute $meridiem';
}

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
        _orderAlarmChannelId,
        'Urgent order alarms',
        description: 'Keeps ringing until the pending order is handled.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('order_bell'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
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
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
        unawaited(showPersistentOrderAlarm(message));
      });

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
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final data = Uri.splitQueryString(launchResponse?.payload ?? '');
      _openOrdersScreen(
        orderId: data['orderId'] ?? '',
        canteenId: data['canteenId'] ?? '',
      );
    }

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

  Future<void> stopOrderAlarm(String orderId) async {
    if (!_supportsNativePush || orderId.isEmpty) return;
    await _localNotifications.cancel(id: _orderNotificationId(orderId));
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
    await _foregroundMessageSubscription?.cancel();
    _initialized = false;
  }
}
