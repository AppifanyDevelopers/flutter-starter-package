import 'package:firebase_core/firebase_core.dart';

/// Initializes the default Firebase app exactly once, as early as possible
/// in `main()` -- so `CrashlyticsService.init()` can wire `FlutterError.onError`
/// before anything else runs. Push notifications and analytics read
/// [isAvailable] instead of calling `Firebase.initializeApp()` themselves;
/// calling it twice throws a duplicate-app error.
///
/// Inert without a real Firebase project: [init] swallows the failure so the
/// rest of the app works with zero Firebase setup -- see
/// docs/POST_GEN_MANUAL_STEPS.md.
abstract class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _available = false;
  static bool get isAvailable => _available;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (_) {
      _available = false;
    }
  }
}
