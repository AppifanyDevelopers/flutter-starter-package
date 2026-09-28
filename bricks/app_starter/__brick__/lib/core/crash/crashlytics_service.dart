import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_bootstrap.dart';

/// Wires Flutter/platform error reporting to Crashlytics. Inert without a
/// real Firebase project -- guarded by [FirebaseBootstrap.isAvailable], so a
/// freshly generated app just keeps Flutter's default error handling until
/// Firebase is configured (see docs/POST_GEN_MANUAL_STEPS.md).
abstract class CrashlyticsService {
  CrashlyticsService._();

  static Future<void> init() async {
    if (!FirebaseBootstrap.isAvailable) return;

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Keeps the Crashlytics dashboard clean during local development.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  /// For manually reporting a caught, non-fatal error.
  static Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false}) async {
    if (!FirebaseBootstrap.isAvailable) return;
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
    } catch (_) {}
  }
}
