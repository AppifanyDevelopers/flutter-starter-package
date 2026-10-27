import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:mason/mason.dart';

Future<void> _run(
  HookContext context,
  String executable,
  List<String> args,
) async {
  final progress = context.logger.progress('$executable ${args.join(' ')}');
  final result = await Process.run(
    executable,
    args,
    workingDirectory: Directory.current.path,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    progress.fail();
    if ((result.stdout as String).trim().isNotEmpty) {
      context.logger.info(result.stdout as String);
    }
    context.logger.err(result.stderr as String);
    throw Exception('Command failed (${result.exitCode}): $executable ${args.join(' ')}');
  }
  progress.complete();
}

/// flutter_flavorizr's default instruction set also includes `flutter:app`,
/// `flutter:pages`, and `flutter:main`, which overwrite lib/main.dart and
/// lib/app.dart with its own generic scaffold -- destroying everything Mason
/// just rendered. This list keeps only the native (Android/iOS) wiring and
/// `flutter:flavors` (which generates lib/flavors.dart, referenced by our
/// own main.dart). It also skips `assets:download`/`assets:extract`/
/// `*:dummyAssets`/`ios:launchScreen` (cosmetic per-flavor ribbon banner and
/// launch screen customization) since those copy from a bundle fetched by
/// `assets:download`, which would otherwise make generation depend on
/// internet access.
const _flavorizrProcessors = [
  'android:androidManifest',
  'android:flavorizrGradle',
  'android:buildGradle',
  'android:icons',
  'flutter:flavors',
  'ios:podfile',
  'ios:xcconfig',
  'ios:buildTargets',
  'ios:schema',
  'ios:icons',
  'ios:plist',
  'ide:config',
];

/// Wires the Android side of push notifications into the Gradle files
/// `flutter create`/`flutter_flavorizr` generate (not part of `__brick__`,
/// so patched here with anchored regexes rather than hand-maintained --
/// more resilient to Flutter/AGP/Kotlin version bumps):
///
/// 1. The Google Services plugin, applied *conditionally* -- only if
///    `android/app/google-services.json` exists. Applying it unconditionally
///    would fail the build the moment someone generates a project and
///    hasn't run `flutterfire configure` yet, breaking "runs immediately,
///    no setup" for every other feature.
/// 2. Core library desugaring, which `flutter_local_notifications` requires
///    unconditionally (build fails without it, regardless of whether
///    Firebase is configured).
void _wireAndroidPushNotificationsGradle(HookContext context) {
  const googleServicesVersion = '4.4.2';
  const desugarJdkLibsVersion = '2.1.4';

  final settingsFile = File('android/settings.gradle.kts');
  var settings = settingsFile.readAsStringSync();
  if (!settings.contains('com.google.gms.google-services')) {
    settings = settings.replaceFirstMapped(
      RegExp(r'id\("org\.jetbrains\.kotlin\.android"\)[^\n]*\n'),
      (match) =>
          '${match.group(0)}'
          '    id("com.google.gms.google-services") version "$googleServicesVersion" apply false\n',
    );
    settingsFile.writeAsStringSync(settings);
  }

  final appBuildFile = File('android/app/build.gradle.kts');
  var appBuild = appBuildFile.readAsStringSync();

  if (!appBuild.contains('isCoreLibraryDesugaringEnabled')) {
    appBuild = appBuild.replaceFirstMapped(
      RegExp(r'compileOptions \{\n'),
      (match) => '${match.group(0)}        isCoreLibraryDesugaringEnabled = true\n',
    );
  }

  if (!appBuild.contains('com.google.gms.google-services')) {
    appBuild = '''
$appBuild
// Only applied once a real Firebase config file is dropped in -- see
// docs/POST_GEN_MANUAL_STEPS.md. Keeps the app buildable with zero setup.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Required unconditionally by flutter_local_notifications.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:$desugarJdkLibsVersion")
}
''';
  }

  appBuildFile.writeAsStringSync(appBuild);

  context.logger.detail('Wired Android push notification Gradle config.');
}

/// Firebase's iOS SDK requires a higher minimum deployment target (15.0)
/// than `flutter create`'s default (13.0) -- `pod install` fails otherwise.
/// Patches the three places Xcode/CocoaPods read this from. Run *after*
/// flutter_flavorizr's iOS processors so this edit is the final word
/// regardless of what they touch.
void _wireIosDeploymentTarget(HookContext context) {
  const target = '15.0';

  final podfile = File('ios/Podfile');
  podfile.writeAsStringSync(
    podfile.readAsStringSync().replaceFirst(
      RegExp(r"#\s*platform :ios, '[\d.]+'"),
      "platform :ios, '$target'",
    ),
  );

  final frameworkInfo = File('ios/Flutter/AppFrameworkInfo.plist');
  frameworkInfo.writeAsStringSync(
    frameworkInfo.readAsStringSync().replaceFirstMapped(
      RegExp(r'(<key>MinimumOSVersion</key>\s*<string>)[\d.]+(</string>)'),
      (match) => '${match.group(1)}$target${match.group(2)}',
    ),
  );

  final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
  pbxproj.writeAsStringSync(
    pbxproj.readAsStringSync().replaceAll(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;'),
      'IPHONEOS_DEPLOYMENT_TARGET = $target;',
    ),
  );

  context.logger.detail('Set iOS deployment target to $target for Firebase.');
}

/// `image_picker` crashes at runtime on iOS without a photo-library usage
/// description in `Info.plist` -- inserts it before the closing `</dict>`,
/// the same anchored-patch approach as the other iOS fixes above. Gallery-
/// only picking on Android needs no manifest permission on modern targets
/// (the system Photo Picker), and `image_picker`'s own manifest merge
/// handles anything older -- no Android patch needed here.
void _wireIosPhotoPermissions(HookContext context) {
  final infoPlist = File('ios/Runner/Info.plist');
  var contents = infoPlist.readAsStringSync();
  if (!contents.contains('NSPhotoLibraryUsageDescription')) {
    contents = contents.replaceFirst(
      '</dict>\n</plist>',
      '\t<key>NSPhotoLibraryUsageDescription</key>\n'
          '\t<string>Used to let you choose a profile photo.</string>\n'
          '</dict>\n</plist>',
    );
    infoPlist.writeAsStringSync(contents);
  }

  context.logger.detail('Added NSPhotoLibraryUsageDescription to Info.plist.');
}

/// `image_cropper`'s Android implementation (uCrop) needs its activity
/// declared in the manifest -- inserted before `</application>`, run after
/// flavorizr's `android:androidManifest` processor so it's the final word.
/// iOS needs no configuration for this package.
void _wireAndroidImageCropper(HookContext context) {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  var contents = manifest.readAsStringSync();
  if (!contents.contains('UCropActivity')) {
    contents = contents.replaceFirst(
      '</application>',
      '        <activity\n'
          '            android:name="com.yalantis.ucrop.UCropActivity"\n'
          '            android:screenOrientation="portrait"\n'
          '            android:theme="@style/Theme.AppCompat.Light.NoActionBar" />\n'
          '    </application>',
    );
    manifest.writeAsStringSync(contents);
  }

  context.logger.detail('Added UCropActivity to AndroidManifest.xml.');
}

/// A monochrome status-bar icon for Android notifications (white on
/// transparent, as Android requires) plus Firebase's default-icon/colour
/// metadata, so pushes shown by the system while the app is closed use it too.
/// iOS has no custom notification icon: it always shows the app icon.
void _wireAndroidNotificationIcon(HookContext context) {
  final drawable = File('android/app/src/main/res/drawable/ic_stat_notification.xml');
  drawable.parent.createSync(recursive: true);
  drawable.writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,22c1.1,0 2,-0.9 2,-2h-4c0,1.1 0.89,2 2,2zM18,16v-5c0,-3.07 -1.64,-5.64 -4.5,-6.32V4c0,-0.83 -0.67,-1.5 -1.5,-1.5s-1.5,0.67 -1.5,1.5v0.68C7.63,5.36 6,7.92 6,11v5l-2,2v1h16v-1l-2,-2z" />
</vector>
''');

  final manifest = File('android/app/src/main/AndroidManifest.xml');
  var contents = manifest.readAsStringSync();
  if (!contents.contains('default_notification_icon')) {
    contents = contents.replaceFirst(
      '</application>',
      '        <meta-data\n'
          '            android:name="com.google.firebase.messaging.default_notification_icon"\n'
          '            android:resource="@drawable/ic_stat_notification" />\n'
          '    </application>',
    );
    manifest.writeAsStringSync(contents);
  }

  context.logger.detail('Added the Android notification icon.');
}

/// `permission_handler` only reports a permission as grantable when the platform
/// is told the app may ask for it:
/// * iOS: each permission is compiled in through a `PERMISSION_*` preprocessor
///   flag in the Podfile (Apple rejects apps that link permission code they
///   never use), so only the three this app asks for are enabled.
/// * Android: the manifest must declare them (camera marked non-required so
///   Play doesn't hide the app from devices without one), plus INTERNET, which
///   `flutter create` only puts in the debug and profile manifests.
void _wirePermissions(HookContext context) {
  final podfile = File('ios/Podfile');
  var pods = podfile.readAsStringSync();
  if (!pods.contains('PERMISSION_CAMERA')) {
    pods = pods.replaceFirstMapped(
      RegExp(r'( *)flutter_additional_ios_build_settings\(target\)\n'),
      (m) =>
          m.group(0)! +
          '    target.build_configurations.each do |config|\n'
              "      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['\$(inherited)']\n"
              "      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] += [\n"
              "        'PERMISSION_CAMERA=1',\n"
              "        'PERMISSION_PHOTOS=1',\n"
              "        'PERMISSION_NOTIFICATIONS=1',\n"
              '      ]\n'
              '    end\n',
    );
    podfile.writeAsStringSync(pods);
  }

  final manifest = File('android/app/src/main/AndroidManifest.xml');
  var xml = manifest.readAsStringSync();
  if (!xml.contains('android.permission.CAMERA')) {
    xml = xml.replaceFirst(
      RegExp(r'<application'),
      '<uses-permission android:name="android.permission.INTERNET"/>\n'
          '  <uses-permission android:name="android.permission.CAMERA"/>\n'
          '  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
          '  <uses-feature android:name="android.hardware.camera" android:required="false"/>\n'
          '  <application',
    );
    manifest.writeAsStringSync(xml);
  }
  context.logger.detail('Declared camera/notification permissions for Android and iOS.');
}

/// `image_picker`'s camera source crashes on iOS without a camera usage
/// description. (The photo-library string is added by [_wireIosPhotoPermissions].)
void _wireIosCameraPermission(HookContext context) {
  final infoPlist = File('ios/Runner/Info.plist');
  var contents = infoPlist.readAsStringSync();
  if (!contents.contains('NSCameraUsageDescription')) {
    contents = contents.replaceFirst(
      '</dict>\n</plist>',
      '\t<key>NSCameraUsageDescription</key>\n'
          '\t<string>Used to let you take a profile photo.</string>\n'
          '</dict>\n</plist>',
    );
    infoPlist.writeAsStringSync(contents);
  }
}

/// Draws a diagonal corner ribbon at the top-left of [source] and saves it to
/// [target]. White text on a coloured band, so a staging/DI build is obvious
/// on the home screen.
void _drawIconRibbon({
  required String source,
  required String target,
  required String label,
  required img.Color color,
}) {
  final icon = img.decodePng(File(source).readAsBytesSync())!;
  final s = icon.width;
  final w = s.toDouble();

  // The band: from the top edge to the left edge, cut at 45 degrees.
  img.fillPolygon(
    icon,
    vertices: [
      img.Point(0, (w * 0.30).round()),
      img.Point((w * 0.30).round(), 0),
      img.Point((w * 0.62).round(), 0),
      img.Point(0, (w * 0.62).round()),
    ],
    color: color,
  );

  // Text: render small, trim, scale to fit the band, rotate, centre on it.
  final text = img.Image(width: 40 * label.length + 40, height: 90, numChannels: 4);
  img.drawString(text, label, font: img.arial48, x: 20, y: 20, color: img.ColorRgb8(255, 255, 255));
  var trimmed = img.trim(text, mode: img.TrimMode.transparent);
  // Fit the band: at most 34% of the icon wide and 8% tall, so short labels
  // like "DI" don't balloon.
  final scale = [w * 0.34 / trimmed.width, w * 0.08 / trimmed.height].reduce((a, b) => a < b ? a : b);
  trimmed = img.copyResize(trimmed, width: (trimmed.width * scale).round(), interpolation: img.Interpolation.cubic);
  final rotated = img.copyRotate(trimmed, angle: -45, interpolation: img.Interpolation.cubic);
  img.compositeImage(
    icon,
    rotated,
    dstX: (w * 0.2275 - rotated.width / 2).round(),
    dstY: (w * 0.2275 - rotated.height / 2).round(),
  );

  File(target).writeAsBytesSync(img.encodePng(icon));
}

/// Per-flavor launcher icons: staging gets a red STAGING ribbon, DI a blue DI
/// ribbon, production keeps the plain icon. `flutter_launcher_icons` picks up
/// the `flutter_launcher_icons-<flavor>.yaml` files and writes each flavor's
/// own Android/iOS icon set. Must run before that tool does.
void _writeFlavorIcons(HookContext context) {
  // A real icon supplied by scripts/create_app.dart replaces the placeholder
  // before any ribbon copy is drawn from it.
  final customIcon = Platform.environment['APP_STARTER_ICON'];
  if (customIcon != null && customIcon.isNotEmpty && File(customIcon).existsSync()) {
    File(customIcon).copySync('assets/logo/icon.png');
  }

  const flavors = {
    'staging': ('STAGING', 0xFFD32F2F),
    'di': ('DI', 0xFF1976D2),
  };
  for (final entry in flavors.entries) {
    final (label, argb) = entry.value;
    _drawIconRibbon(
      source: 'assets/logo/icon.png',
      target: 'assets/logo/icon_${entry.key}.png',
      label: label,
      color: img.ColorRgba8((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF, 255),
    );
    File('flutter_launcher_icons-${entry.key}.yaml').writeAsStringSync('''
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo/icon_${entry.key}.png"
''');
  }
  // Production keeps the plain icon, but still needs its own set: flavorizr
  // points iOS at `AppIcon-<flavor>`, so `AppIcon-production` must exist.
  File('flutter_launcher_icons-production.yaml').writeAsStringSync('''
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo/icon.png"
''');
  context.logger.detail('Drew the STAGING and DI launcher icon ribbons.');
}

/// Google Sign-In on iOS needs a URL scheme (the reversed client ID) and a
/// `GIDClientID` key in `Info.plist`. The *real* values only exist once a
/// developer has their actual `GoogleService-Info.plist` (added after
/// generation, same as the rest of Firebase) -- these are inserted as
/// clearly-marked placeholders pointing at exactly which keys to copy in,
/// the same "scaffolded but needs a real value dropped in" tier as
/// everything else Firebase-shaped in this template. No Android patch is
/// needed: it resolves its OAuth client from `google-services.json` (already
/// the shared Firebase manual step) plus a SHA fingerprint registered in the
/// console, which is a per-developer-machine credential that can't be
/// generated either way.
void _wireIosGoogleSignIn(HookContext context) {
  final infoPlist = File('ios/Runner/Info.plist');
  var contents = infoPlist.readAsStringSync();
  if (!contents.contains('GIDClientID')) {
    contents = contents.replaceFirst(
      '</dict>\n</plist>',
      '\t<!-- Google Sign-In: replace both values below with your real\n'
          '\tGoogleService-Info.plist\'s CLIENT_ID / REVERSED_CLIENT_ID -- see\n'
          '\tdocs/POST_GEN_MANUAL_STEPS.md. -->\n'
          '\t<key>GIDClientID</key>\n'
          '\t<string>REPLACE_WITH_CLIENT_ID</string>\n'
          '\t<key>CFBundleURLTypes</key>\n'
          '\t<array>\n'
          '\t\t<dict>\n'
          '\t\t\t<key>CFBundleTypeRole</key>\n'
          '\t\t\t<string>Editor</string>\n'
          '\t\t\t<key>CFBundleURLSchemes</key>\n'
          '\t\t\t<array>\n'
          '\t\t\t\t<string>REPLACE_WITH_REVERSED_CLIENT_ID</string>\n'
          '\t\t\t</array>\n'
          '\t\t</dict>\n'
          '\t</array>\n'
          '</dict>\n</plist>',
    );
    infoPlist.writeAsStringSync(contents);
  }

  context.logger.detail('Added placeholder Google Sign-In keys to Info.plist.');
}

/// Apple Sign-In needs the `com.apple.developer.applesignin` entitlement.
/// `flutter create` doesn't generate a `Runner.entitlements` file or wire
/// `CODE_SIGN_ENTITLEMENTS` into any build configuration by default
/// (confirmed empirically -- there is nothing to patch), so this creates one
/// and points every flavor's Debug/Release/Profile xcconfig at it. Simpler
/// and more resilient than inserting `CODE_SIGN_ENTITLEMENTS` into each of
/// project.pbxproj's many `XCBuildConfiguration` blocks directly.
void _wireIosAppleSignIn(HookContext context) {
  final entitlementsFile = File('ios/Runner/Runner.entitlements');
  if (!entitlementsFile.existsSync()) {
    entitlementsFile.writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>com.apple.developer.applesignin</key>
\t<array>
\t\t<string>Default</string>
\t</array>
</dict>
</plist>
''');
  }

  for (final flavor in ['staging', 'di', 'production']) {
    for (final buildMode in ['Debug', 'Release', 'Profile']) {
      final xcconfig = File('ios/Flutter/$flavor$buildMode.xcconfig');
      if (!xcconfig.existsSync()) continue;
      var contents = xcconfig.readAsStringSync();
      if (!contents.contains('CODE_SIGN_ENTITLEMENTS')) {
        contents = '$contents\nCODE_SIGN_ENTITLEMENTS=Runner/Runner.entitlements\n';
        xcconfig.writeAsStringSync(contents);
      }
    }
  }

  context.logger.detail('Added the Apple Sign-In entitlement.');
}

/// Scaffolds build-only Fastlane lanes for both platforms. Deploy lanes
/// (TestFlight/Play internal testing) aren't included -- they need real
/// credentials (App Store Connect API key / Play service account), a bigger
/// step documented as a manual upgrade path in
/// docs/POST_GEN_MANUAL_STEPS.md, not scaffolded here. `flutter build` is
/// shelled out to rather than invoking Gradle/Xcode directly, since that's
/// what actually bundles Flutter's assets correctly.
void _scaffoldFastlane(HookContext context, {required String applicationId}) {
  Directory('android/fastlane').createSync(recursive: true);
  File('android/fastlane/Appfile').writeAsStringSync('''
# See ../../docs/POST_GEN_MANUAL_STEPS.md before adding deploy lanes -- this
# file only needs a value here once you do.
package_name("$applicationId")
''');
  File('android/fastlane/Fastfile').writeAsStringSync('''
default_platform(:android)

# Secrets are passed at build time, never committed: if dart_defines/<flavor>.json
# exists (see dart_defines/README.md) it is handed to the build.
def dart_defines(flavor)
  File.exist?("../../dart_defines/#{flavor}.json") ? " --dart-define-from-file=dart_defines/#{flavor}.json" : ""
end

platform :android do
  desc "Build a staging debug APK"
  lane :build_staging do
    sh("flutter build apk --debug --flavor staging -t lib/main.dart" + dart_defines("staging"), chdir: "../..")
  end

  desc "Build a DI debug APK"
  lane :build_di do
    sh("flutter build apk --debug --flavor di -t lib/main.dart" + dart_defines("di"), chdir: "../..")
  end

  desc "Build a production release APK"
  lane :build_production do
    # --obfuscate strips identifiers from crash reports -- --split-debug-info
    # writes the symbols needed to de-obfuscate them back. Upload that folder
    # to Crashlytics once it's configured (see docs/POST_GEN_MANUAL_STEPS.md),
    # or crashes from this build can never be symbolicated.
    sh(
      "flutter build apk --release --flavor production -t lib/main.dart " \\
      "--obfuscate --split-debug-info=build/debug-info/android-production" + dart_defines("production"),
      chdir: "../.."
    )
  end
end
''');

  Directory('ios/fastlane').createSync(recursive: true);
  File('ios/fastlane/Appfile').writeAsStringSync('''
# Production bundle id; staging is "$applicationId.staging", DI is "$applicationId.di".
# See ../../docs/POST_GEN_MANUAL_STEPS.md before adding deploy lanes -- an
# apple_id and team need to go here once you do.
app_identifier("$applicationId")
''');
  File('ios/fastlane/Fastfile').writeAsStringSync('''
default_platform(:ios)

# Secrets are passed at build time, never committed: if dart_defines/<flavor>.json
# exists (see dart_defines/README.md) it is handed to the build.
def dart_defines(flavor)
  File.exist?("../../dart_defines/#{flavor}.json") ? " --dart-define-from-file=dart_defines/#{flavor}.json" : ""
end

platform :ios do
  desc "Build a staging IPA (unsigned)"
  lane :build_staging do
    # --obfuscate strips identifiers from crash reports -- --split-debug-info
    # writes the symbols needed to de-obfuscate them back. Upload that folder
    # to Crashlytics once it's configured (see docs/POST_GEN_MANUAL_STEPS.md),
    # or crashes from this build can never be symbolicated.
    sh(
      "flutter build ios --release --flavor staging -t lib/main.dart --no-codesign " \\
      "--obfuscate --split-debug-info=build/debug-info/ios-staging" + dart_defines("staging"),
      chdir: "../.."
    )
  end

  desc "Build a DI IPA (unsigned)"
  lane :build_di do
    sh(
      "flutter build ios --release --flavor di -t lib/main.dart --no-codesign" + dart_defines("di"),
      chdir: "../.."
    )
  end

  desc "Build a production IPA (unsigned)"
  lane :build_production do
    sh(
      "flutter build ios --release --flavor production -t lib/main.dart --no-codesign " \\
      "--obfuscate --split-debug-info=build/debug-info/ios-production" + dart_defines("production"),
      chdir: "../.."
    )
  end
end
''');

  context.logger.detail('Scaffolded build-only Fastlane lanes for android/ and ios/.');
}

/// `flutter create` sets the Android `namespace` and the `MainActivity`
/// package to `<org>.<project_name>`. The `applicationId` per flavor already
/// comes from flavorizr.yaml, but a namespace like `com.acme.my_app` would
/// still carry the project name (and an underscore), so rewrite both to the
/// application id and move `MainActivity.kt` to match.
void _alignAndroidIdentifiers(HookContext context, String applicationId) {
  final gradle = File('android/app/build.gradle.kts');
  if (gradle.existsSync()) {
    gradle.writeAsStringSync(
      gradle
          .readAsStringSync()
          .replaceFirstMapped(
            RegExp(r'namespace\s*=\s*"[^"]*"'),
            (_) => 'namespace = "$applicationId"',
          )
          // The defaultConfig id is flutter create's `<org>.<project_name>`;
          // flavor ids (already exact) are left alone.
          .replaceAllMapped(RegExp(r'applicationId\s*=\s*"([^"]*)"'), (m) {
        final value = m.group(1)!;
        return value == applicationId || value == '$applicationId.staging' || value == '$applicationId.di'
            ? m.group(0)!
            : 'applicationId = "$applicationId"';
      }),
    );
  }

  final kotlinRoot = Directory('android/app/src/main/kotlin');
  if (!kotlinRoot.existsSync()) return;
  final activities =
      kotlinRoot.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('MainActivity.kt')).toList();
  if (activities.isEmpty) return;

  final old = activities.first;
  final target = File('${kotlinRoot.path}/${applicationId.replaceAll('.', '/')}/MainActivity.kt');
  if (old.path != target.path) {
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(
      old.readAsStringSync().replaceFirstMapped(RegExp(r'package\s+[\w.]+'), (_) => 'package $applicationId'),
    );
    old.deleteSync();
    // Remove directories left empty by the move.
    var dir = old.parent;
    while (dir.path != kotlinRoot.path && dir.existsSync() && dir.listSync().isEmpty) {
      final parent = dir.parent;
      dir.deleteSync();
      dir = parent;
    }
  }
  context.logger.detail('Aligned Android namespace and MainActivity package to $applicationId.');
}

/// flutter create leaves a camelCased base id (e.g. `com.acme.myApp`) on the
/// non-flavored build configurations and the RunnerTests target. Flavored
/// configurations already carry the right ids from flavorizr.
void _alignIosBundleIds(HookContext context, String applicationId) {
  final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
  if (!pbxproj.existsSync()) return;
  final fixed = pbxproj.readAsStringSync().replaceAllMapped(
    RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9._]+);'),
    (m) {
      final value = m.group(1)!;
      if (value.endsWith('.RunnerTests')) return 'PRODUCT_BUNDLE_IDENTIFIER = $applicationId.RunnerTests;';
      if (value == applicationId || value == '$applicationId.staging' || value == '$applicationId.di') {
        return m.group(0)!;
      }
      return 'PRODUCT_BUNDLE_IDENTIFIER = $applicationId;';
    },
  );
  pbxproj.writeAsStringSync(fixed);
  context.logger.detail('Aligned iOS bundle ids to $applicationId.');
}


/// Rewrites `lib/core/theme/app_palette.dart` with the colours from
/// `APP_STARTER_COLORS_JSON` (a `{"neutral900": "101B30", ...}` file written by
/// `scripts/create_app.dart` from the user's `color.xml`). Names the file does
/// not define keep the defaults, so the theme's required entries always exist.
void _applyPaletteOverrides(HookContext context) {
  final overridesPath = Platform.environment['APP_STARTER_COLORS_JSON'];
  if (overridesPath == null || overridesPath.isEmpty || !File(overridesPath).existsSync()) return;

  final overrides = (jsonDecode(File(overridesPath).readAsStringSync()) as Map).cast<String, String>();
  final file = File('lib/core/theme/app_palette.dart');
  final colors = <String, String>{
    for (final m in RegExp(r'static const Color (\w+) = Color\(0xFF([0-9A-Fa-f]{6})\);')
        .allMatches(file.readAsStringSync()))
      m.group(1)!: m.group(2)!.toUpperCase(),
  };
  overrides.forEach((name, hex) => colors[name] = hex.toUpperCase());

  int order(String n) {
    final family = RegExp(r'^[a-z]+').firstMatch(n)!.group(0)!;
    final rank = ['neutral', 'grey', 'warning'].indexOf(family);
    final step = int.tryParse(n.substring(family.length)) ?? 0;
    return (rank < 0 ? 9 : rank) * 100000 + step;
  }

  final names = colors.keys.toList()..sort((a, b) => order(a).compareTo(order(b)));
  final buffer = StringBuffer()
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..writeln('/// Neutral, grey and warning ramps used for text, borders and status colours.')
    ..writeln('///')
    ..writeln('/// Generated from your `color.xml` by `scripts/create_app.dart` (only the')
    ..writeln('/// `warning*`, `neutral*` and `grey*` entries are read; anything it does not')
    ..writeln('/// define keeps the default). The theme reads `neutral50`, `neutral200`,')
    ..writeln('/// `neutral300`, `neutral500`, `neutral600` and `neutral900`.')
    ..writeln('abstract class AppPalette {')
    ..writeln('  AppPalette._();');
  String? last;
  for (final n in names) {
    final family = RegExp(r'^[a-z]+').firstMatch(n)!.group(0)!;
    if (family != last) {
      buffer
        ..writeln()
        ..writeln('  // $family');
      last = family;
    }
    buffer.writeln('  static const Color $n = Color(0xFF${colors[n]});');
  }
  buffer.writeln('}');
  file.writeAsStringSync(buffer.toString());
  context.logger.detail('Applied ${overrides.length} palette colours from your color file.');
}

/// Files that move into `<base>_design_system` / `<base>_common` in a monorepo,
/// relative to the app root. Both sets only import each other and Flutter (plus
/// `shimmer`), so they can be lifted out without touching anything else.
const _designSystemFiles = [
  'lib/core/theme/app_colors.dart',
  'lib/core/theme/app_palette.dart',
  'lib/core/theme/app_theme.dart',
];

const _commonFiles = [
  'lib/core/widgets/app_text_form_field.dart',
  'lib/core/widgets/app_outlined_button.dart',
  'lib/core/widgets/app_scaffold.dart',
  'lib/core/widgets/custom_app_bar.dart',
  'lib/core/widgets/app_shimmer.dart',
  'lib/core/widgets/app_loading_widget.dart',
  'lib/core/widgets/app_error_widget.dart',
  'lib/core/widgets/password_rules_checklist.dart',
  'lib/core/widgets/step_indicator.dart',
  'lib/core/widgets/app_bottom_sheet.dart',
  'lib/core/widgets/avatar_picker.dart',
  'lib/core/validators/validators.dart',
  'lib/core/utils/keyboard.dart',
];

String _normalize(String path) {
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(part);
    }
  }
  return out.join('/');
}

/// Turns the generated single app into one app of a Melos monorepo
/// (`<root>/apps/<app>`, `<root>/packages/<base>_design_system`,
/// `<root>/packages/<base>_common`), the layout used by rentsy. When the
/// packages already exist (adding a second app) they are left alone and the
/// app just depends on them.
Future<void> _applyMonorepo(HookContext context, {required String base, required String projectName}) async {
  final appDir = Directory.current.absolute;
  final root = appDir.parent.parent;
  if (appDir.parent.path.split(Platform.pathSeparator).last != 'apps') {
    throw Exception('Monorepo mode expects the app to be generated into <root>/apps/<app> (got ${appDir.path}).');
  }

  final dsName = '${base}_design_system';
  final commonName = '${base}_common';
  final dsDir = Directory('${root.path}/packages/$dsName');
  final commonDir = Directory('${root.path}/packages/$commonName');
  final createDs = !dsDir.existsSync();
  final createCommon = !commonDir.existsSync();

  // 1. Rewrite the app's imports of moved files, before moving them.
  final dsBarrel = 'package:$dsName/$dsName.dart';
  final commonBarrel = 'package:$commonName/$commonName.dart';
  final targets = <String, String>{
    for (final f in _designSystemFiles) f: dsBarrel,
    for (final f in _commonFiles) f: commonBarrel,
  };
  final importPattern = RegExp('^(\\s*(?:import|export)\\s+)([\'"])([^\'"]+)\\2', multiLine: true);
  for (final dir in [Directory('lib'), Directory('test')].where((d) => d.existsSync())) {
    for (final file in dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final fileDir = file.parent.path;
      var changed = false;
      var text = file.readAsStringSync().replaceAllMapped(importPattern, (m) {
        final uri = m.group(3)!;
        String? resolved;
        if (uri.startsWith('package:$projectName/')) {
          resolved = 'lib/${uri.substring('package:$projectName/'.length)}';
        } else if (!uri.contains(':')) {
          resolved = _normalize('$fileDir/$uri');
        }
        final replacement = resolved == null ? null : targets[resolved];
        if (replacement == null) return m.group(0)!;
        changed = true;
        return '${m.group(1)}${m.group(2)}$replacement${m.group(2)}';
      });
      if (!changed) continue;
      // Several moved files imported by one file collapse to a single import.
      final seen = <String>{};
      text = text.split('\n').where((line) {
        final isBarrel = line.contains(dsBarrel) || line.contains(commonBarrel);
        return !isBarrel || seen.add(line.trim());
      }).join('\n');
      file.writeAsStringSync(text);
    }
  }

  // 2. Move (or discard, if the package already exists) the shared files.
  void moveInto(Directory pkg, List<String> files, {required bool create}) {
    for (final f in files) {
      final source = File(f);
      if (create) {
        final target = File('${pkg.path}/${f.replaceFirst('lib/core/', 'lib/src/')}');
        target.parent.createSync(recursive: true);
        target.writeAsStringSync(source.readAsStringSync());
      }
      source.deleteSync();
    }
  }

  moveInto(dsDir, _designSystemFiles, create: createDs);
  moveInto(commonDir, _commonFiles, create: createCommon);

  String exports(List<String> files) =>
      files.map((f) => "export 'src/${f.replaceFirst('lib/core/', '')}';").join('\n');

  // 3. Package scaffolding.
  final appPubspec = File('pubspec.yaml');
  final pubspecText = appPubspec.readAsStringSync();
  String constraint(String name, String fallback) =>
      RegExp('^  $name: (.+)\$', multiLine: true).firstMatch(pubspecText)?.group(1)?.trim() ?? fallback;

  if (createDs) {
    Directory('${dsDir.path}/lib').createSync(recursive: true);
    File('${dsDir.path}/lib/$dsName.dart').writeAsStringSync('${exports(_designSystemFiles)}\n');
    File('${dsDir.path}/pubspec.yaml').writeAsStringSync('''
name: $dsName
description: Shared design tokens for $base apps (colours, palette and ThemeData).
version: 0.0.1
publish_to: none

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=1.17.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_lints: ${constraint('flutter_lints', '^6.0.0')}
''');
    File('${dsDir.path}/analysis_options.yaml').writeAsStringSync('include: package:flutter_lints/flutter.yaml\n');
  }
  if (createCommon) {
    Directory('${commonDir.path}/lib').createSync(recursive: true);
    File('${commonDir.path}/lib/$commonName.dart').writeAsStringSync('${exports(_commonFiles)}\n');
    File('${commonDir.path}/pubspec.yaml').writeAsStringSync('''
name: $commonName
description: Shared widgets and validators for $base apps.
version: 0.0.1
publish_to: none

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=1.17.0"

dependencies:
  flutter:
    sdk: flutter
  shimmer: ${constraint('shimmer', '^3.0.0')}

dev_dependencies:
  flutter_lints: ${constraint('flutter_lints', '^6.0.0')}
''');
    File('${commonDir.path}/analysis_options.yaml').writeAsStringSync('include: package:flutter_lints/flutter.yaml\n');
  }

  // 4. Root workspace files, only for a brand-new monorepo.
  if (!File('${root.path}/melos.yaml').existsSync()) {
    File('${root.path}/melos.yaml').writeAsStringSync('''
name: ${base}_monorepo

packages:
  - packages/**
  - apps/**

command:
  bootstrap:
    usePubspecOverrides: true

scripts:
  analyze:
    run: melos exec -- flutter analyze
    description: Run flutter analyze in every package.

  test:
    run: melos exec --dir-exists="test" -- flutter test
    description: Run flutter test in every package that has a test directory.
''');
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: ${base}_monorepo
publish_to: 'none'

environment:
  sdk: ^3.10.4

dev_dependencies:
  melos: ^6.3.0
''');
    File('${root.path}/.gitignore').writeAsStringSync('.dart_tool/\nbuild/\npubspec_overrides.yaml\n.idea/\n*.iml\n');
    File('${root.path}/README.md').writeAsStringSync('''
# ${base}_monorepo

```
apps/            one folder per app
packages/
  $dsName/      colours, palette, ThemeData
  $commonName/      shared widgets and validators
```

Run `dart pub global activate melos && melos bootstrap` once, then `melos run analyze`
and `melos run test`.
''');
  }

  // 5. Point the app at the packages.
  appPubspec.writeAsStringSync(
    pubspecText.replaceFirst(
      'dependencies:\n  flutter:\n    sdk: flutter\n',
      'dependencies:\n  flutter:\n    sdk: flutter\n'
          '  $dsName:\n    path: ../../packages/$dsName\n'
          '  $commonName:\n    path: ../../packages/$commonName\n',
    ),
  );

  context.logger.detail(
    'Monorepo: ${createDs ? 'created' : 'reused'} $dsName, ${createCommon ? 'created' : 'reused'} $commonName.',
  );
}

Future<void> run(HookContext context) async {
  final projectName = context.vars['project_name'] as String;
  final applicationId = context.vars['application_id'] as String;
  final applicationIdParent = context.vars['application_id_parent'] as String;

  // 1. Lay down native android/ios folders with the correct project name and
  //    org (the application id minus its last segment; step 5b rewrites the
  //    ids flutter create derives from it). No --overwrite: Mason has already rendered pubspec.yaml, lib/**,
  //    and test/widget_test.dart, so `flutter create` only fills in what's
  //    missing (android/, ios/, .metadata, analysis_options.yaml) and skips
  //    everything that already exists.
  await _run(context, 'flutter', [
    'create',
    '--project-name', projectName,
    '--org', applicationIdParent,
    '--platforms', 'android,ios',
    '.',
  ]);

  // 2. Wire Android push-notification Gradle config in, before flavorizr
  //    touches these same files.
  _wireAndroidPushNotificationsGradle(context);

  // 3. Scaffold Fastlane (build-only lanes) for both platforms -- these are
  //    brand new files, so they don't need to run before/after any other
  //    step, just after step 1 has created android/ and ios/.
  _scaffoldFastlane(context, applicationId: applicationId);

  // 4. Resolve dependencies so flavorizr/launcher_icons (dev dependencies)
  //    are available to run.
  await _run(context, 'flutter', ['pub', 'get']);

  // 5. Wire up staging/production flavors from the already-rendered
  //    flavorizr.yaml. Deliberately NOT using change_app_package_name here:
  //    flutter create --org already set the correct base id, and running it
  //    after flavorizr would blindly collapse the distinct per-flavor
  //    bundle ids flavorizr just set up back to one.
  await _run(context, 'dart', [
    'run', 'flutter_flavorizr',
    '--force',
    '--processors', _flavorizrProcessors.join(','),
  ]);

  // 5b. flutter create derived ids from `<org>.<project_name>` (underscores,
  //     camelCase). Make every remaining id exactly the application id.
  _alignAndroidIdentifiers(context, applicationId);
  _alignIosBundleIds(context, applicationId);

  // 6. Bump the iOS deployment target for Firebase, add the photo-library
  //    permission string for image_picker, register image_cropper's Android
  //    activity, and wire the placeholder Google Sign-In keys + Apple
  //    Sign-In entitlement, after flavorizr's processors have had their
  //    turn touching these same files.
  _wireIosDeploymentTarget(context);
  _wireIosPhotoPermissions(context);
  _wireAndroidImageCropper(context);
  _wireAndroidNotificationIcon(context);
  _wireIosCameraPermission(context);
  _wirePermissions(context);
  _wireIosGoogleSignIn(context);
  _wireIosAppleSignIn(context);

  // 6b. Optional user colours for the palette (scripts/create_app.dart).
  _applyPaletteOverrides(context);

  // 7. Stamp app icons from the placeholder logo shipped in assets/logo/,
  //    with a ribbon on the staging and DI flavors' copies.
  _writeFlavorIcons(context);
  await _run(context, 'dart', ['run', 'flutter_launcher_icons']);

  // 7b. Monorepo layout (scripts/create_app.dart sets this; plain `mason make`
  //     leaves it unset and gets a standalone app).
  final monorepoBase = Platform.environment['APP_STARTER_MONOREPO_BASE'];
  if (monorepoBase != null && monorepoBase.isNotEmpty) {
    await _applyMonorepo(context, base: monorepoBase, projectName: projectName);
  }

  // 8. Final sync pass after native config changes.
  await _run(context, 'flutter', ['pub', 'get']);

  context.logger.success('\n"$projectName" is ready.');
  context.logger.info('''
Next steps:
  cd .
  flutter run --flavor staging -t lib/main.dart --dart-define=FLAVOR=staging

See docs/POST_GEN_MANUAL_STEPS.md in the flutter_starter_pack repo for what
is intentionally NOT automated (real backend, Firebase, app icon artwork,
iOS signing, store listings).
''');
}
