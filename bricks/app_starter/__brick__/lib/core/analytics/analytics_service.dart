import 'package:firebase_analytics/firebase_analytics.dart';

import '../firebase/firebase_bootstrap.dart';

/// A fixed catalogue of analytics events -- deliberately not a generic
/// `log(String name)` passthrough, so event names can't drift between call
/// sites. Uses GA4's own recommended events (`logSignUp`/`logLogin`) where
/// the SDK provides them. Inert without a real Firebase project, same as
/// [CrashlyticsService]/`PushNotificationService`.
abstract class AnalyticsService {
  AnalyticsService._();

  static Future<void> logSignUp() => _guard(
        () => FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email'),
      );

  static Future<void> logLogin() => _guard(
        () => FirebaseAnalytics.instance.logLogin(loginMethod: 'email'),
      );

  static Future<void> logLogout() => _guard(
        () => FirebaseAnalytics.instance.logEvent(name: 'logout'),
      );

  static Future<void> _guard(Future<void> Function() action) async {
    if (!FirebaseBootstrap.isAvailable) return;
    try {
      await action();
    } catch (_) {}
  }
}
