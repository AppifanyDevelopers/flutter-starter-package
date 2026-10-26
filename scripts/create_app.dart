// Interactive generator for the app_starter brick.
//
// Usage: dart scripts/create_app.dart
//
// Asks for everything Mason's own `brick.yaml` vars need (project name, application id,
// seed color, API URLs) plus three things Mason can't template because
// they're real per-client files, not text: an app icon image, and the two
// Firebase config files. No external packages -- run directly with `dart`,
// no `pub get` required.

import 'dart:convert';
import 'dart:io';

final _projectNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');
final _orgPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*)+$');
final _hexColorPattern = RegExp(r'^#?[0-9a-fA-F]{6}$');

Future<void> main() async {
  stdout.writeln('=== flutter_starter_pack: new project generator ===\n');

  final outputPath = _ask(
    'Where should the new project be created? (path, will be created)',
    required: true,
  );
  final projectName = _ask(
    'Package/project name (lower_snake_case, e.g. acme_rentals)',
    validator: (v) => _projectNamePattern.hasMatch(v)
        ? null
        : 'Must be lower_snake_case, starting with a letter (e.g. acme_rentals).',
  );
  final appName = _ask('App display name (e.g. Acme Rentals)', required: true);
  final applicationId = _ask(
    'Application ID, used exactly as typed for Android and iOS (e.g. com.acme.rentals)',
    required: true,
    validator: (v) => _orgPattern.hasMatch(v)
        ? null
        : 'Reverse-DNS, at least two segments, letters and digits only -- no underscores or hyphens '
            '(e.g. com.acme.rentals).',
  );
  final seedColor = _ask(
    'Brand color (hex, e.g. #6750A4)',
    defaultValue: '#6750A4',
    validator: (v) => _hexColorPattern.hasMatch(v)
        ? null
        : 'Must be a 6-digit hex color, with or without # (e.g. #6750A4).',
  );
  final description = _ask(
    'Short project description',
    defaultValue: 'A Flutter app generated from app_starter.',
  );
  final apiStaging = _normalizeUrl(_ask(
    'Staging API base URL, including the /api prefix (endpoints are appended to it)',
    defaultValue: 'https://staging-api.example.com/api',
    validator: (v) => v.startsWith('https://') ? null : 'Must start with https://.',
  ));
  final apiProduction = _normalizeUrl(_ask(
    'Production API base URL, including the /api prefix (endpoints are appended to it)',
    defaultValue: 'https://api.example.com/api',
    validator: (v) => v.startsWith('https://') ? null : 'Must start with https://.',
  ));
  final iosAppStoreUrl = _ask(
    'iOS App Store URL for the update dialog (Enter to use a placeholder until the app exists)',
    defaultValue: 'https://apps.apple.com/app/id0000000000',
    validator: (v) => v.startsWith('https://apps.apple.com/') || v.startsWith('https://itunes.apple.com/')
        ? null
        : 'Must be an App Store link, e.g. https://apps.apple.com/app/id1234567890.',
  );

  stdout.writeln('\n--- Firebase (required: push, Crashlytics, Analytics, Google Sign-In) ---');
  stdout.writeln('Create the Android apps for "$applicationId" AND "$applicationId.staging",');
  stdout.writeln('enable the Google sign-in provider, then download both files.');
  final googleServicesPath = _askRequiredFile(
    'google-services.json (Android Firebase config)',
    extensions: ['.json'],
    validate: (path) => _validateGoogleServices(path, applicationId),
  );
  final googleServiceInfoPlistPath = _askRequiredFile(
    'GoogleService-Info.plist (iOS Firebase config)',
    extensions: ['.plist'],
    validate: (path) => _validatePlist(path, applicationId),
  );

  stdout.writeln('\n--- Optional ---');
  final iconPath = _askOptionalFile('App icon (PNG, ideally 1024x1024)', extensions: ['.png']);

  stdout.writeln('\n--- Summary ---');
  stdout.writeln('Output:              $outputPath');
  stdout.writeln('Project name:        $projectName');
  stdout.writeln('App name:            $appName');
  stdout.writeln('Application ID:      $applicationId (staging: $applicationId.staging)');
  stdout.writeln('Seed color:          $seedColor');
  stdout.writeln('Description:         $description');
  stdout.writeln('API (staging):       $apiStaging');
  stdout.writeln('API (production):    $apiProduction');
  stdout.writeln('iOS App Store URL:   $iosAppStoreUrl');
  stdout.writeln('App icon:            ${iconPath ?? '(skipped -- placeholder icon kept)'}');
  stdout.writeln('google-services.json: $googleServicesPath');
  stdout.writeln('GoogleService-Info.plist: $googleServiceInfoPlistPath');
  stdout.write('\nGenerate with these values? [Y/n] ');
  final confirmed = _readLine().toLowerCase();
  if (confirmed == 'n' || confirmed == 'no') {
    stdout.writeln('Cancelled.');
    exit(0);
  }

  final repoRoot = File.fromUri(Platform.script).parent.parent.path;
  final outputDir = Directory(outputPath).absolute;
  outputDir.createSync(recursive: true);

  final varsFile = File('${Directory.systemTemp.createTempSync('app_starter_vars').path}/vars.json');
  varsFile.writeAsStringSync(jsonEncode({
    'project_name': projectName,
    'app_name': appName,
    'application_id': applicationId,
    'seed_color': seedColor,
    'description': description,
    'api_base_url_staging': apiStaging,
    'api_base_url_production': apiProduction,
    'ios_app_store_url': iosAppStoreUrl,
  }));

  stdout.writeln('\nResolving the brick...');
  await _runInherited('mason', ['get'], workingDirectory: repoRoot);

  stdout.writeln('\nGenerating "$projectName"...');
  await _runInherited(
    'mason',
    ['make', 'app_starter', '-o', outputDir.path, '-c', varsFile.path, '--on-conflict', 'overwrite'],
    workingDirectory: repoRoot,
  );

  if (iconPath != null) {
    stdout.writeln('\nApplying your app icon...');
    File(iconPath).copySync('${outputDir.path}/assets/logo/icon.png');
    await _runInherited('dart', ['run', 'flutter_launcher_icons'], workingDirectory: outputDir.path);
  }

  stdout.writeln('\nCopying google-services.json into android/app/...');
  Directory('${outputDir.path}/android/app').createSync(recursive: true);
  File(googleServicesPath).copySync('${outputDir.path}/android/app/google-services.json');

  stdout.writeln('Copying GoogleService-Info.plist into ios/Runner/...');
  Directory('${outputDir.path}/ios/Runner').createSync(recursive: true);
  File(googleServiceInfoPlistPath).copySync('${outputDir.path}/ios/Runner/GoogleService-Info.plist');

  stdout.writeln('Filling the Google Sign-In keys in ios/Runner/Info.plist from the plist...');
  _fillGoogleSignInKeys(googleServiceInfoPlistPath, '${outputDir.path}/ios/Runner/Info.plist');

  stdout.writeln('\n=== Done ===');
  stdout.writeln('"$appName" is ready at ${outputDir.path}');
  stdout.writeln('\nNext steps:');
  stdout.writeln('  cd ${outputDir.path}');
  stdout.writeln('  flutter run --flavor staging -t lib/main.dart --dart-define=FLAVOR=staging');
  stdout.writeln('\nStill manual (cannot be scripted):');
  stdout.writeln('  - Xcode: drag GoogleService-Info.plist into the Runner target, enable Push');
  stdout.writeln('    Notifications + Background Modes, upload the APNs key to Firebase.');
  stdout.writeln('  - Sign In with Apple: enable the capability for your App ID.');
  stdout.writeln('  - Android Google Sign-In: add your debug/release SHA-1 and SHA-256 to Firebase.');
  stdout.writeln('  See docs/POST_GEN_MANUAL_STEPS.md.');
}

/// Reads a line, or aborts if stdin is closed (otherwise a required prompt
/// would loop forever when input is piped or the terminal is gone).
String _readLine() {
  final line = stdin.readLineSync();
  if (line == null) {
    stderr.writeln('\nInput ended before all required answers were given. Cancelled.');
    exit(64);
  }
  return line.trim();
}

String _ask(
  String prompt, {
  String? defaultValue,
  bool required = false,
  String? Function(String)? validator,
}) {
  while (true) {
    final suffix = defaultValue != null ? ' [$defaultValue]' : '';
    stdout.write('$prompt$suffix: ');
    final input = _readLine();
    final value = input.isEmpty ? (defaultValue ?? '') : input;

    if (value.isEmpty && required) {
      stdout.writeln('  This field is required.');
      continue;
    }
    final error = value.isEmpty ? null : validator?.call(value);
    if (error != null) {
      stdout.writeln('  $error');
      continue;
    }
    return value;
  }
}

String? _askOptionalFile(String label, {required List<String> extensions}) {
  while (true) {
    stdout.write('$label (path, Enter to skip): ');
    final input = _readLine();
    if (input.isEmpty) return null;

    final path = _expandHome(input);
    if (!File(path).existsSync()) {
      stdout.writeln('  No file found at "$path". Try again, or press Enter to skip.');
      continue;
    }
    final lowerPath = path.toLowerCase();
    if (!extensions.any(lowerPath.endsWith)) {
      stdout.writeln('  Expected a ${extensions.join(' or ')} file. Try again, or press Enter to skip.');
      continue;
    }
    return path;
  }
}

String _expandHome(String path) {
  if (!path.startsWith('~')) return path;
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  return path.replaceFirst('~', home);
}

Future<void> _runInherited(
  String executable,
  List<String> args, {
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln('\nCommand failed ($exitCode): $executable ${args.join(' ')}');
    if (executable == 'mason') {
      stderr.writeln('Is Mason CLI installed? Try: dart pub global activate mason_cli');
    }
    exit(exitCode);
  }
}

String _normalizeUrl(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

/// Required file prompt: re-asks until the path exists, has the right
/// extension and passes [validate] (which returns an error message or null).
String _askRequiredFile(
  String label, {
  required List<String> extensions,
  required String? Function(String path) validate,
}) {
  while (true) {
    stdout.write('$label (path, required): ');
    final input = _readLine();
    if (input.isEmpty) {
      stdout.writeln('  This file is required.');
      continue;
    }
    final path = _expandHome(input);
    if (!File(path).existsSync()) {
      stdout.writeln('  No file found at "$path". Try again.');
      continue;
    }
    if (!extensions.any(path.toLowerCase().endsWith)) {
      stdout.writeln('  Expected a ${extensions.join(' or ')} file. Try again.');
      continue;
    }
    final error = validate(path);
    if (error != null) {
      stdout.writeln('  $error');
      continue;
    }
    return path;
  }
}

/// Both flavors build from this one file, so it must list the production AND
/// staging package, and Google sign-in must be enabled (a type-3 OAuth client).
String? _validateGoogleServices(String path, String applicationId) {
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    return 'Not a valid google-services.json (could not parse JSON).';
  }
  final clients = (json['client'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
  final packages = {
    for (final c in clients)
      if ((c['client_info'] as Map?)?['android_client_info']?['package_name'] is String)
        (c['client_info'] as Map)['android_client_info']['package_name'] as String,
  };
  final production = applicationId;
  final staging = '$production.staging';
  final missing = [production, staging].where((p) => !packages.contains(p)).toList();
  if (missing.isNotEmpty) {
    return 'This file lists ${packages.isEmpty ? 'no Android apps' : packages.join(', ')} but is missing '
        '${missing.join(' and ')}. Add those Android apps in Firebase and download the file again.';
  }
  final hasWebClient = clients.any((c) =>
      (c['oauth_client'] as List<dynamic>? ?? []).any((o) => o is Map && o['client_type'] == 3));
  if (!hasWebClient) {
    return 'Google sign-in is not enabled (no OAuth web client in the file). Enable the Google '
        'provider under Authentication > Sign-in method, then re-download.';
  }
  return null;
}

Map<String, String> _readPlistStrings(String path) {
  final xml = File(path).readAsStringSync();
  return {
    for (final m in RegExp(r'<key>([^<]+)</key>\s*<string>([^<]*)</string>').allMatches(xml))
      m.group(1)!: m.group(2)!,
  };
}

/// The plist must carry the Google keys and belong to this app's bundle id.
String? _validatePlist(String path, String applicationId) {
  final values = _readPlistStrings(path);
  for (final key in ['CLIENT_ID', 'REVERSED_CLIENT_ID', 'BUNDLE_ID']) {
    if (!values.containsKey(key)) {
      return 'GoogleService-Info.plist has no $key. Enable the Google sign-in provider in Firebase '
          'and re-download the file.';
    }
  }
  final production = applicationId;
  final bundleId = values['BUNDLE_ID']!;
  if (bundleId != production && bundleId != '$production.staging') {
    return 'BUNDLE_ID is "$bundleId" but this project uses $production (production) / '
        '$production.staging (staging). Add a matching iOS app in Firebase and re-download.';
  }
  if (bundleId != production) {
    stdout.writeln('  Note: this plist is for the staging bundle id only; the production flavor '
        'needs its own GoogleService-Info.plist before release.');
  } else {
    stdout.writeln('  Note: this plist is for the production bundle id; the staging flavor '
        '($production.staging) needs its own plist to use Firebase.');
  }
  return null;
}

/// Replaces the placeholders post_gen left in Info.plist with the real
/// Google Sign-In values, so the buttons work without hand-editing.
void _fillGoogleSignInKeys(String plistPath, String infoPlistPath) {
  final values = _readPlistStrings(plistPath);
  final info = File(infoPlistPath);
  var contents = info.readAsStringSync();
  contents = contents
      .replaceAll('REPLACE_WITH_REVERSED_CLIENT_ID', values['REVERSED_CLIENT_ID']!)
      .replaceAll('REPLACE_WITH_CLIENT_ID', values['CLIENT_ID']!);
  info.writeAsStringSync(contents);
}
