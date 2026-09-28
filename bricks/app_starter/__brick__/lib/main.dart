import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';

import 'core/build_variants/environment_entry_points.dart';
import 'core/crash/crashlytics_service.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'flavors.dart';

// Set by `--dart-define=FLAVOR=staging` (or `production`); flutter_flavorizr
// wires this on each per-flavor run/build configuration it generates.
const _flavorName = String.fromEnvironment('FLAVOR', defaultValue: 'staging');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  F.appFlavor = Flavor.values.firstWhere(
    (flavor) => flavor.name == _flavorName,
    orElse: () => Flavor.staging,
  );

  await dotenv.load(
    fileName: F.appFlavor == Flavor.production ? '.env.production' : '.env.staging',
  );
  await GetStorage.init();

  // As early as possible, so Crashlytics can catch errors during the rest
  // of boot. Push notifications (initialized later, from SplashController)
  // and analytics read FirebaseBootstrap.isAvailable rather than calling
  // Firebase.initializeApp() themselves -- see core/firebase/firebase_bootstrap.dart.
  await FirebaseBootstrap.init();
  await CrashlyticsService.init();

  runApp(
    F.appFlavor == Flavor.production ? const ProductionEntryPoint() : const StagingEntryPoint(),
  );
}
