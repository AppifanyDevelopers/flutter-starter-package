import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../firebase/firebase_bootstrap.dart';
import '../routes/app_routes.dart';

/// Wraps Firebase Cloud Messaging + local notification display.
///
/// Inert by design until a real `google-services.json`/`GoogleService-Info.plist`
/// is added (see docs/POST_GEN_MANUAL_STEPS.md) -- reads [FirebaseBootstrap.isAvailable]
/// rather than calling `Firebase.initializeApp()` itself, so the rest of the
/// app keeps working without a real Firebase project.
///
/// Notification payload contract: a push that should navigate somewhere on
/// tap must include a `route` key in its `data` payload matching one of the
/// named routes in [AppRoutes] (e.g. `{"route": "/settings/notifications"}`).
class PushNotificationService {
  PushNotificationService._();

  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'default_channel';
  static const _androidChannelName = 'General';

  static Future<void> init() async {
    if (!FirebaseBootstrap.isAvailable) return;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _navigateToRoute(response.payload),
    );

    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _navigateToRoute(message.data['route'] as String?),
    );
  }

  /// Call once after the app's first route has been decided, to redirect
  /// into a specific screen if the app was cold-started by tapping a push
  /// notification (rather than launched normally). Returns the target route
  /// name, or null if there wasn't one.
  static Future<String?> consumeInitialRoute() async {
    if (!FirebaseBootstrap.isAvailable) return null;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    final route = message?.data['route'] as String?;
    return _isKnownRoute(route) ? route : null;
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(_androidChannelId, _androidChannelName),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['route'] as String?,
    );
  }

  static void _navigateToRoute(String? route) {
    if (_isKnownRoute(route)) Get.toNamed(route!);
  }

  static bool _isKnownRoute(String? route) =>
      route != null && AppRoutes.pages.any((page) => page.name == route);
}

/// Must be a top-level function (not a class method) -- Firebase runs it on
/// a separate background isolate, which has no access to this app's state.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
