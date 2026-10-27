import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';

import 'core/build_variants/environment_entry_points.dart';
import 'core/build_variants/flavor_resolver.dart';
import 'core/crash/crashlytics_service.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/telemetry/telemetry.dart';
import 'flavors.dart';

// `--dart-define=FLAVOR=staging` (or `di` / `production`) wins, as the
// flutter_flavorizr run configurations pass it; otherwise `--flavor <name>`
// decides. See core/build_variants/flavor_resolver.dart.
const _flavorOverride = String.fromEnvironment('FLAVOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  F.appFlavor = Flavor.values.firstWhere(
    (flavor) => flavor.name == resolveFlavorName(explicit: _flavorOverride, platformFlavor: appFlavor),
    orElse: () => Flavor.staging,
  );

  await dotenv.load(
    fileName: switch (F.appFlavor) {
      Flavor.production => '.env.production',
      Flavor.di => '.env.di',
      Flavor.staging => '.env.staging',
    },
  );
  await GetStorage.init();

  // As early as possible, so Crashlytics can catch errors during the rest
  // of boot. Push notifications (initialized later, from SplashController)
  // and analytics read FirebaseBootstrap.isAvailable rather than calling
  // Firebase.initializeApp() themselves -- see core/firebase/firebase_bootstrap.dart.
  await FirebaseBootstrap.init();
  await CrashlyticsService.init();
  await Telemetry.setFlavor(F.appFlavor.name);

  runApp(
    switch (F.appFlavor) {
      Flavor.production => const ProductionEntryPoint(),
      Flavor.di => const DiEntryPoint(),
      Flavor.staging => const StagingEntryPoint(),
    },
  );
}
