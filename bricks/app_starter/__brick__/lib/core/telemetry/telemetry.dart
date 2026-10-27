import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../firebase/firebase_bootstrap.dart';

/// Where "who is this user / which flavor is this build / what went wrong"
/// goes. A swappable seam so call sites stay one-liners and tests can assert on
/// them without Firebase.
abstract class TelemetrySink {
  /// Tags every later crash and analytics event with the build flavor.
  Future<void> setFlavor(String flavor);

  /// Ties later crashes and analytics events to [userId] (a backend id, never
  /// an email or name).
  Future<void> identify(String userId);

  Future<void> clearUser();

  /// A caught, non-fatal error worth seeing in the dashboard.
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});
}

/// Crashlytics + Analytics. Inert without a real Firebase project, like the
/// other Firebase services (see [FirebaseBootstrap]).
class FirebaseTelemetrySink implements TelemetrySink {
  Future<void> _guard(Future<void> Function() action) async {
    if (!FirebaseBootstrap.isAvailable) return;
    try {
      await action();
    } catch (_) {}
  }

  @override
  Future<void> setFlavor(String flavor) => _guard(() async {
        await FirebaseCrashlytics.instance.setCustomKey('flavor', flavor);
        await FirebaseAnalytics.instance.setUserProperty(name: 'flavor', value: flavor);
      });

  @override
  Future<void> identify(String userId) => _guard(() async {
        await FirebaseCrashlytics.instance.setUserIdentifier(userId);
        await FirebaseAnalytics.instance.setUserId(id: userId);
      });

  @override
  Future<void> clearUser() => _guard(() async {
        await FirebaseCrashlytics.instance.setUserIdentifier('');
        await FirebaseAnalytics.instance.setUserId(id: null);
      });

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) => _guard(
        () => FirebaseCrashlytics.instance.recordError(error, stack, reason: reason, fatal: false),
      );
}

/// Static entry point. Swap [sink] in tests.
abstract class Telemetry {
  Telemetry._();

  static TelemetrySink sink = FirebaseTelemetrySink();

  static Future<void> setFlavor(String flavor) => sink.setFlavor(flavor);
  static Future<void> identify(String userId) => sink.identify(userId);
  static Future<void> clearUser() => sink.clearUser();
  static Future<void> recordError(Object error, StackTrace? stack, {String? reason}) =>
      sink.recordError(error, stack, reason: reason);
}
