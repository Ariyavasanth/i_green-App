import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../firebase_options.dart';
import '../../employee/domain/employee.dart';
import '../domain/notification_repository.dart';

/// Android notification channel matching AndroidManifest.xml and Cloud Functions.
const String kFcmAndroidChannelId = 'igreen_high_importance_channel';
const String kFcmAndroidChannelName = 'Igreen Notifications';
const String kFcmAndroidChannelDescription =
    'Push notifications for leave, on-duty, incentive, and project updates.';

/// Web Push VAPID key from Firebase Console -> Project Settings -> Cloud Messaging
/// -> Web configuration -> Web Push certificates.
/// Pass via `--dart-define=FCM_WEB_VAPID_KEY=YOUR_PUBLIC_VAPID_KEY` or paste below.
const String kFcmWebVapidKey = String.fromEnvironment(
  'FCM_WEB_VAPID_KEY',
  defaultValue: '',
);

/// Top-level background handler required by firebase_messaging on Android/iOS.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('FCM background init notice: $e');
  }
}

class FcmPushService {
  FcmPushService({
    required NotificationRepository notificationRepository,
  }) : _notificationRepository = notificationRepository;

  final NotificationRepository _notificationRepository;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _initializing = false;
  Employee? _activeEmployee;
  String? _currentToken;
  String? _lastSyncedFingerprint;
  void Function(String route)? _onNavigate;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  bool get _isFcmSupportedPlatform =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  bool get _isLocalNotificationSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _platformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return 'other';
    }
  }

  /// Registers the callback used when a user taps a push notification.
  void setNavigationHandler(void Function(String route) onNavigate) {
    _onNavigate = onNavigate;
  }

  Future<void> initialize() async {
    if (_initialized || _initializing || !_isFcmSupportedPlatform) return;
    _initializing = true;

    try {
      final messaging = FirebaseMessaging.instance;

      // Request notification permissions (Android 13+, iOS, Web)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (!kIsWeb) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      if (_isLocalNotificationSupportedPlatform) {
        await _initLocalNotifications();
      }

      // Listen for foreground messages
      _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listen for notification taps when app is in background
      _onMessageOpenedAppSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap that launched the app from a terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Listen for FCM token refreshes
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
        final previousToken = _currentToken;
        _currentToken = newToken;
        final employee = _activeEmployee;
        if (employee != null) {
          if (previousToken != null &&
              previousToken.isNotEmpty &&
              previousToken != newToken) {
            await _notificationRepository.removeFcmToken(token: previousToken);
          }
          await _notificationRepository.saveFcmToken(
            employee: employee,
            token: newToken,
            platform: _platformName,
          );
          _lastSyncedFingerprint = _buildFingerprint(employee, newToken);
        }
      });

      _initialized = true;
    } catch (e) {
      debugPrint('FcmPushService initialize notice: $e');
    } finally {
      _initializing = false;
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map && decoded['route'] is String) {
            final route = (decoded['route'] as String).trim();
            if (route.isNotEmpty) {
              _onNavigate?.call(route);
            }
          }
        } catch (_) {
          if (payload.startsWith('/')) {
            _onNavigate?.call(payload);
          }
        }
      },
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        kFcmAndroidChannelId,
        kFcmAndroidChannelName,
        description: kFcmAndroidChannelDescription,
        importance: Importance.max,
        playSound: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString() ?? 'Igreen';
    final body =
        message.notification?.body ?? message.data['message']?.toString() ?? '';
    final route = message.data['route']?.toString() ?? '';

    if (_isLocalNotificationSupportedPlatform) {
      final notificationId =
          message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

      const androidDetails = AndroidNotificationDetails(
        kFcmAndroidChannelId,
        kFcmAndroidChannelName,
        channelDescription: kFcmAndroidChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: Color(0xFF9CC70A),
        playSound: true,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _localNotifications.show(
        notificationId,
        title,
        body,
        const NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
        ),
        payload: jsonEncode({'route': route}),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route']?.toString().trim() ?? '';
    if (route.isNotEmpty && route.startsWith('/')) {
      _onNavigate?.call(route);
    }
  }

  /// Syncs the device FCM token with Firestore whenever the logged-in employee
  /// changes, or removes it on logout.
  Future<void> syncForEmployee(Employee? employee) async {
    if (!_isFcmSupportedPlatform) return;

    if (employee == null) {
      _activeEmployee = null;
      _lastSyncedFingerprint = null;
      final tokenToRemove = _currentToken;
      if (tokenToRemove != null && tokenToRemove.isNotEmpty) {
        await _notificationRepository.removeFcmToken(token: tokenToRemove);
      }
      return;
    }

    _activeEmployee = employee;
    await initialize();

    try {
      final messaging = FirebaseMessaging.instance;
      String? token;
      if (kIsWeb) {
        if (kFcmWebVapidKey.isEmpty) {
          debugPrint(
            'FCM Web VAPID key is not set. Pass --dart-define=FCM_WEB_VAPID_KEY=<your-key> '
            'to enable Web Push token registration.',
          );
          return;
        }
        token = await messaging.getToken(vapidKey: kFcmWebVapidKey);
      } else {
        token = await messaging.getToken();
      }

      if (token == null || token.trim().isEmpty) return;

      _currentToken = token;
      final fingerprint = _buildFingerprint(employee, token);
      if (fingerprint == _lastSyncedFingerprint) return;

      await _notificationRepository.saveFcmToken(
        employee: employee,
        token: token,
        platform: _platformName,
      );
      _lastSyncedFingerprint = fingerprint;
    } catch (e) {
      debugPrint('FcmPushService token sync notice: $e');
    }
  }

  String _buildFingerprint(Employee employee, String token) {
    final sortedPerms = List<String>.from(employee.accessPermissions)..sort();
    return '${employee.id}|${employee.employeeId}|${employee.userType}|'
        '${employee.isSuperAdmin}|${sortedPerms.join(",")}|$token';
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
  }
}
