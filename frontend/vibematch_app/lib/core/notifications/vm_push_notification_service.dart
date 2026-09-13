import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_api_service.dart';
import '../network/vm_api_config.dart';

@pragma('vm:entry-point')
Future<void> vmFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep background work lightweight.
}

@pragma('vm:entry-point')
void vmLocalNotificationBackgroundTapHandler(NotificationResponse response) {
  // Keep background tap handling lightweight.
}

class VmPushNotificationService {
  VmPushNotificationService._();

  static final VmPushNotificationService instance =
      VmPushNotificationService._();

  static const String _incomingCallChannelId = 'funkey_incoming_calls';
  static const String _incomingCallChannelName = 'Incoming calls';
  static const String _generalChannelId = 'funkey_general';
  static const String _generalChannelName = 'FunKey notifications';

  // Keep Firebase/plugin objects lazy. Constructing FirebaseMessaging.instance
  // on an unsupported or unconfigured platform can throw before callers have a
  // chance to apply their platform guards.
  late final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  late final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AuthApiService _authApiService = const AuthApiService();

  bool _initialized = false;

  bool get _supportsCurrentFirebaseConfig {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> initialize() async {
    if (_initialized || !_supportsCurrentFirebaseConfig) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(
        vmFirebaseMessagingBackgroundHandler,
      );

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            vmLocalNotificationBackgroundTapHandler,
      );

      await _createAndroidChannels();
      await _requestPermission();

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      _messaging.onTokenRefresh.listen((token) {
        unawaited(registerCurrentToken(tokenOverride: token));
      });

      await registerCurrentToken();
    } catch (error, stackTrace) {
      _initialized = false;
      debugPrint('Push initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _createAndroidChannels() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    const callChannel = AndroidNotificationChannel(
      _incomingCallChannelId,
      _incomingCallChannelName,
      description: 'Incoming FunKey voice and video call alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const generalChannel = AndroidNotificationChannel(
      _generalChannelId,
      _generalChannelName,
      description: 'General FunKey alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await android.createNotificationChannel(callChannel);
    await android.createNotificationChannel(generalChannel);
  }

  Future<void> _requestPermission() async {
    if (!_supportsCurrentFirebaseConfig) return;

    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> registerCurrentToken({String? tokenOverride}) async {
    if (!_supportsCurrentFirebaseConfig) return;

    try {
      final accessToken = _authApiService.cachedAccessToken;
      if (accessToken == null || accessToken.trim().isEmpty) return;

      final token = tokenOverride ?? await _messaging.getToken();
      if (token == null || token.trim().isEmpty) return;

      final deviceId = await _authApiService.getCurrentDeviceId();
      final platform = switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        TargetPlatform.macOS => 'macos',
        TargetPlatform.windows => 'windows',
        TargetPlatform.linux => 'linux',
        TargetPlatform.fuchsia => 'fuchsia',
      };

      final response = await http.post(
        Uri.parse(VmApiConfig.endpoint('/push/device-token')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'device_id': deviceId,
          'platform': platform,
          'fcm_token': token,
          'app_package': 'com.funkey.app',
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'FCM token registration failed: '
          '${response.statusCode} ${response.body}',
        );
      }
    } catch (error, stackTrace) {
      // Push registration is auxiliary infrastructure and must never make auth
      // or the main application unusable.
      debugPrint('FCM token registration error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> deleteCurrentTokenOnLogout() async {
    if (!_supportsCurrentFirebaseConfig) return;

    try {
      final accessToken = _authApiService.cachedAccessToken;
      if (accessToken == null || accessToken.trim().isEmpty) return;

      final deviceId = await _authApiService.getCurrentDeviceId();
      final response = await http.delete(
        Uri.parse(VmApiConfig.endpoint('/push/device-token/$deviceId')),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'FCM token cleanup failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (error, stackTrace) {
      // Logout/session cleanup must remain successful even when push cleanup
      // cannot reach Firebase or the backend.
      debugPrint('FCM token cleanup error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!_supportsCurrentFirebaseConfig) return;

    final data = message.data;
    final type = data['type']?.toString();
    final isCall = type == 'inbox_call';

    final title = isCall
        ? data['title']?.toString() ?? 'Incoming call'
        : message.notification?.title ?? 'FunKey';

    final body = isCall
        ? data['body']?.toString() ?? 'Incoming FunKey call'
        : message.notification?.body ?? '';

    final androidDetails = isCall
        ? const AndroidNotificationDetails(
            _incomingCallChannelId,
            _incomingCallChannelName,
            channelDescription: 'Incoming FunKey voice and video call alerts',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
            ongoing: false,
            autoCancel: true,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'accept_call',
                'Accept',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                'decline_call',
                'Decline',
                cancelNotification: true,
              ),
            ],
          )
        : const AndroidNotificationDetails(
            _generalChannelId,
            _generalChannelName,
            channelDescription: 'General FunKey alerts',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            autoCancel: true,
            playSound: true,
            enableVibration: true,
          );

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('Push opened: ${message.data}');
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) return;

    final actionId = response.actionId;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      debugPrint('Local notification action=$actionId data=$data');
    } catch (error) {
      debugPrint('Could not parse local notification payload: $error');
    }
  }
}
