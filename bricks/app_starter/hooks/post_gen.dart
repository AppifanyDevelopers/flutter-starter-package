import 'dart:io';

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

  for (final flavor in ['staging', 'production']) {
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
void _scaffoldFastlane(HookContext context, {required String org, required String projectName}) {
  Directory('android/fastlane').createSync(recursive: true);
  File('android/fastlane/Appfile').writeAsStringSync('''
# See ../../docs/POST_GEN_MANUAL_STEPS.md before adding deploy lanes -- this
# file only needs a value here once you do.
package_name("$org.$projectName")
''');
  File('android/fastlane/Fastfile').writeAsStringSync('''
default_platform(:android)

platform :android do
  desc "Build a staging debug APK"
  lane :build_staging do
    sh("flutter build apk --debug --flavor staging -t lib/main.dart", chdir: "../..")
  end

  desc "Build a production release APK"
  lane :build_production do
    # --obfuscate strips identifiers from crash reports -- --split-debug-info
    # writes the symbols needed to de-obfuscate them back. Upload that folder
    # to Crashlytics once it's configured (see docs/POST_GEN_MANUAL_STEPS.md),
    # or crashes from this build can never be symbolicated.
    sh(
      "flutter build apk --release --flavor production -t lib/main.dart " \\
      "--obfuscate --split-debug-info=build/debug-info/android-production",
      chdir: "../.."
    )
  end
end
''');

  Directory('ios/fastlane').createSync(recursive: true);
  File('ios/fastlane/Appfile').writeAsStringSync('''
# Production bundle id; staging is "$org.$projectName.staging".
# See ../../docs/POST_GEN_MANUAL_STEPS.md before adding deploy lanes -- an
# apple_id and team need to go here once you do.
app_identifier("$org.$projectName")
''');
  File('ios/fastlane/Fastfile').writeAsStringSync('''
default_platform(:ios)

platform :ios do
  desc "Build a staging IPA (unsigned)"
  lane :build_staging do
    # --obfuscate strips identifiers from crash reports -- --split-debug-info
    # writes the symbols needed to de-obfuscate them back. Upload that folder
    # to Crashlytics once it's configured (see docs/POST_GEN_MANUAL_STEPS.md),
    # or crashes from this build can never be symbolicated.
    sh(
      "flutter build ios --release --flavor staging -t lib/main.dart --no-codesign " \\
      "--obfuscate --split-debug-info=build/debug-info/ios-staging",
      chdir: "../.."
    )
  end

  desc "Build a production IPA (unsigned)"
  lane :build_production do
    sh(
      "flutter build ios --release --flavor production -t lib/main.dart --no-codesign " \\
      "--obfuscate --split-debug-info=build/debug-info/ios-production",
      chdir: "../.."
    )
  end
end
''');

  context.logger.detail('Scaffolded build-only Fastlane lanes for android/ and ios/.');
}

Future<void> run(HookContext context) async {
  final projectName = context.vars['project_name'] as String;
  final org = context.vars['org'] as String;

  // 1. Lay down native android/ios folders with the correct project name and
  //    org. No --overwrite: Mason has already rendered pubspec.yaml, lib/**,
  //    and test/widget_test.dart, so `flutter create` only fills in what's
  //    missing (android/, ios/, .metadata, analysis_options.yaml) and skips
  //    everything that already exists.
  await _run(context, 'flutter', [
    'create',
    '--project-name', projectName,
    '--org', org,
    '--platforms', 'android,ios',
    '.',
  ]);

  // 2. Wire Android push-notification Gradle config in, before flavorizr
  //    touches these same files.
  _wireAndroidPushNotificationsGradle(context);

  // 3. Scaffold Fastlane (build-only lanes) for both platforms -- these are
  //    brand new files, so they don't need to run before/after any other
  //    step, just after step 1 has created android/ and ios/.
  _scaffoldFastlane(context, org: org, projectName: projectName);

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

  // 6. Bump the iOS deployment target for Firebase, add the photo-library
  //    permission string for image_picker, register image_cropper's Android
  //    activity, and wire the placeholder Google Sign-In keys + Apple
  //    Sign-In entitlement, after flavorizr's processors have had their
  //    turn touching these same files.
  _wireIosDeploymentTarget(context);
  _wireIosPhotoPermissions(context);
  _wireAndroidImageCropper(context);
  _wireIosGoogleSignIn(context);
  _wireIosAppleSignIn(context);

  // 7. Stamp app icons from the placeholder logo shipped in assets/logo/.
  await _run(context, 'dart', ['run', 'flutter_launcher_icons']);

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
