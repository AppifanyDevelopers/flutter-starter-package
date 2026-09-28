// Interactive generator for the app_starter brick.
//
// Usage: dart scripts/create_app.dart
//
// Asks for everything Mason's own `brick.yaml` vars need (project name, org,
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
  final org = _ask(
    'Organization / package name prefix, reverse-DNS (e.g. com.acme)',
    validator: (v) => _orgPattern.hasMatch(v)
        ? null
        : 'Must be reverse-DNS with at least two segments (e.g. com.acme).',
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
  final apiStaging = _ask(
    'Staging API base URL (used once you swap in a real backend)',
    defaultValue: 'https://staging-api.example.com/api/v1',
    validator: (v) => v.startsWith('https://') ? null : 'Must start with https://.',
  );
  final apiProduction = _ask(
    'Production API base URL (used once you swap in a real backend)',
    defaultValue: 'https://api.example.com/api/v1',
    validator: (v) => v.startsWith('https://') ? null : 'Must start with https://.',
  );

  stdout.writeln('\n--- Optional: real branding/Firebase files ---');
  stdout.writeln('Press Enter to skip any of these -- they can be added later.');
  final iconPath = _askOptionalFile('App icon (PNG, ideally 1024x1024)', extensions: ['.png']);
  final googleServicesPath = _askOptionalFile(
    'google-services.json (Android Firebase config)',
    extensions: ['.json'],
  );
  final googleServiceInfoPlistPath = _askOptionalFile(
    'GoogleService-Info.plist (iOS Firebase config)',
    extensions: ['.plist'],
  );

  stdout.writeln('\n--- Summary ---');
  stdout.writeln('Output:              $outputPath');
  stdout.writeln('Project name:        $projectName');
  stdout.writeln('App name:            $appName');
  stdout.writeln('Org:                 $org');
  stdout.writeln('Seed color:          $seedColor');
  stdout.writeln('Description:         $description');
  stdout.writeln('API (staging):       $apiStaging');
  stdout.writeln('API (production):    $apiProduction');
  stdout.writeln('App icon:            ${iconPath ?? '(skipped -- placeholder icon kept)'}');
  stdout.writeln('google-services.json: ${googleServicesPath ?? '(skipped -- push disabled until added)'}');
  stdout.writeln('GoogleService-Info.plist: ${googleServiceInfoPlistPath ?? '(skipped -- push disabled until added)'}');
  stdout.write('\nGenerate with these values? [Y/n] ');
  final confirmed = (stdin.readLineSync() ?? '').trim().toLowerCase();
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
    'org': org,
    'seed_color': seedColor,
    'description': description,
    'api_base_url_staging': apiStaging,
    'api_base_url_production': apiProduction,
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

  if (googleServicesPath != null) {
    stdout.writeln('\nCopying google-services.json into android/app/...');
    Directory('${outputDir.path}/android/app').createSync(recursive: true);
    File(googleServicesPath).copySync('${outputDir.path}/android/app/google-services.json');
    _checkAndroidPackageName(googleServicesPath, org, projectName);
  }

  if (googleServiceInfoPlistPath != null) {
    stdout.writeln('\nCopying GoogleService-Info.plist into ios/Runner/...');
    Directory('${outputDir.path}/ios/Runner').createSync(recursive: true);
    File(googleServiceInfoPlistPath).copySync('${outputDir.path}/ios/Runner/GoogleService-Info.plist');
  }

  stdout.writeln('\n=== Done ===');
  stdout.writeln('"$appName" is ready at ${outputDir.path}');
  stdout.writeln('\nNext steps:');
  stdout.writeln('  cd ${outputDir.path}');
  stdout.writeln('  flutter run --flavor staging -t lib/main.dart --dart-define=FLAVOR=staging');
  if (googleServiceInfoPlistPath != null) {
    stdout.writeln('\nGoogleService-Info.plist was copied to disk, but Xcode will not bundle it');
    stdout.writeln('automatically -- open ios/Runner.xcworkspace and drag the file into the');
    stdout.writeln('Runner target (see docs/POST_GEN_MANUAL_STEPS.md).');
  }
  if (googleServicesPath == null && googleServiceInfoPlistPath == null) {
    stdout.writeln('\nPush notifications are inert until Firebase config is added -- see');
    stdout.writeln('docs/POST_GEN_MANUAL_STEPS.md.');
  }
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
    final input = stdin.readLineSync()?.trim() ?? '';
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
    final input = stdin.readLineSync()?.trim() ?? '';
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

/// Best-effort sanity check: warns (doesn't block) if the provided
/// google-services.json doesn't list this project's applicationId, since
/// the Google Services Gradle plugin will otherwise fail the build later
/// with a less obvious error.
void _checkAndroidPackageName(String googleServicesPath, String org, String projectName) {
  try {
    final json = jsonDecode(File(googleServicesPath).readAsStringSync()) as Map<String, dynamic>;
    final clients = json['client'] as List<dynamic>? ?? [];
    final packageNames = clients
        .map((c) => (c as Map<String, dynamic>)['client_info']
            as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map((info) => (info['android_client_info'] as Map<String, dynamic>?)?['package_name'] as String?)
        .whereType<String>()
        .toSet();

    final expectedProduction = '$org.$projectName';
    final expectedStaging = '$expectedProduction.staging';
    if (!packageNames.contains(expectedProduction) && !packageNames.contains(expectedStaging)) {
      stdout.writeln('  Warning: google-services.json lists ${packageNames.join(', ')},');
      stdout.writeln('  but this project uses $expectedProduction / $expectedStaging.');
      stdout.writeln('  The Android build will fail until these match -- add matching Android');
      stdout.writeln('  apps in your Firebase project, or re-download the config file.');
    }
  } catch (_) {
    // Not valid JSON in the expected shape -- let the real build surface the error.
  }
}
