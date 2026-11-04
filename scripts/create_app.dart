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

// Colour is used only on a real terminal (or when FORCE_COLOR is set) and never
// when NO_COLOR is set, so piped input/output (CI, tests) stays plain text.
final _useColor = !Platform.environment.containsKey('NO_COLOR') &&
    (stdout.hasTerminal || Platform.environment.containsKey('FORCE_COLOR'));
String _paint(String code, String text) => _useColor && text.isNotEmpty ? '\x1B[${code}m$text\x1B[0m' : text;

/// A question the user must answer.
String _question(String text) => _paint('1;36', text);

/// The default shown after a question.
String _hint(String text) => _paint('2', text);

/// A validation message.
String _bad(String text) => _paint('31', text);

/// A warning or note.
String _warn(String text) => _paint('33', text);

/// A section heading.
String _heading(String text) => _paint('1;35', text);

Future<void> main() async {
  stdout.writeln(_heading('=== flutter_starter_pack: new project generator ===\n'));

  final projectName = _ask(
    'Package/project name (lower_snake_case, e.g. acme_rentals)',
    required: true,
    validator: (v) => _projectNamePattern.hasMatch(v)
        ? null
        : 'Must be lower_snake_case, starting with a letter (e.g. acme_rentals).',
  );
  // Projects are always created on the Desktop, in a folder named after the
  // project (<Desktop>/<project_name>); no need to ask.
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  final parentPath = '$home/Desktop';
  final parentDir = Directory(parentPath).absolute;

  // Layout. Polyrepo (default): <parent>/<project>. Monorepo: a Melos workspace
  // <parent>/<folder>/ with apps/<project> plus shared design-system and common
  // packages, like rentsy. Either way the project gets its own folder, so its
  // files can never be spread into a folder that already holds other things.
  final monorepo = _askChoice(
    'Repository layout: polyrepo (one app per repo) or monorepo (Melos workspace)?',
    choices: const ['polyrepo', 'monorepo'],
    defaultValue: 'polyrepo',
  ) == 'monorepo';

  String? monorepoFolder;
  String? monorepoBase;
  late final String outputPath;
  if (monorepo) {
    monorepoFolder = _ask(
      'Monorepo folder name (created inside the parent folder, e.g. acme_monorepo)',
      required: true,
      validator: (v) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(v)
          ? null
          : 'Letters, digits, ., _ and - only.',
    );
    final rootDir = Directory('${parentDir.path}/$monorepoFolder');
    final existingBase = _detectMonorepoBase(rootDir);
    if (existingBase != null) {
      monorepoBase = existingBase;
      stdout.writeln('  Existing monorepo found: reusing packages ${existingBase}_design_system and '
          '${existingBase}_common (they are not modified).');
    } else {
      monorepoBase = _ask(
        'Base package name, lower_snake_case (e.g. acme -> acme_design_system, acme_common)',
        required: true,
        validator: (v) => _projectNamePattern.hasMatch(v)
            ? null
            : 'Must be lower_snake_case, starting with a letter (e.g. acme).',
      );
    }
    outputPath = '${rootDir.path}/apps/$projectName';
  } else {
    outputPath = '${parentDir.path}/$projectName';
  }
  final existing = Directory(outputPath);
  if (existing.existsSync() && existing.listSync().isNotEmpty) {
    stderr.writeln('\n"$outputPath" already exists and is not empty. Pick another parent folder '
        'or project name, or delete it first.');
    exit(64);
  }
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

  stdout.writeln(_heading('\n--- Firebase (required: push, Crashlytics, Analytics, Google Sign-In) ---'));
  stdout.writeln('Create the Android apps for "$applicationId", "$applicationId.staging" AND "$applicationId.di",');
  stdout.writeln('enable the Google sign-in provider. Android uses ONE google-services.json for all three flavors;');
  stdout.writeln('iOS needs a separate GoogleService-Info.plist per flavor (three iOS apps in Firebase).');
  final googleServicesPath = _askRequiredFile(
    'google-services.json (Android Firebase config)',
    extensions: ['.json'],
    validate: (path) => _validateGoogleServices(path, applicationId),
  );
  final plistPaths = <String, String>{};
  for (final flavor in _flavors) {
    final bundleId = _bundleIdFor(flavor, applicationId);
    plistPaths[flavor] = _askRequiredFile(
      'GoogleService-Info.plist for the $flavor flavor (iOS bundle id $bundleId)',
      extensions: ['.plist'],
      validate: (path) => _validatePlist(path, bundleId, flavor),
    );
  }

  stdout.writeln(_heading('\n--- Colours, fonts and images (generated with flutter_gen) ---'));
  stdout.writeln('Colours become ColorName.<name> (e.g. ColorName.primary500), fonts FontFamily.<name>,');
  stdout.writeln('images Assets.images.<name>. Press Enter to skip any of these.');
  final colorsXmlPath = _askOptionalFile(
    'color.xml with your colours (e.g. neutral500, primary500)',
    extensions: ['.xml'],
  );
  final colorEntries = colorsXmlPath == null ? null : _readColorEntries(colorsXmlPath);
  if (colorEntries != null && monorepo && _detectMonorepoBase(Directory('${parentDir.path}/$monorepoFolder')) != null) {
    stdout.writeln(_warn('  Note: the existing design-system package already owns the colours and fonts, so these are ignored.'));
  }
  final fontsDir = _askOptionalDirectory(
    'Fonts folder (.ttf / .otf files, e.g. Poppins-Regular.ttf, Poppins-Bold.ttf)',
    containing: const ['.ttf', '.otf'],
  );
  final imagesDir = _askOptionalDirectory(
    'Images folder (copied into assets/images)',
    containing: const ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg'],
  );

  stdout.writeln(_heading('\n--- Optional ---'));
  final iconPath = _askOptionalFile('App icon (PNG, ideally 1024x1024)', extensions: ['.png']);

  stdout.writeln(_heading('\n--- Summary ---'));
  stdout.writeln('Layout:              ${monorepo ? 'monorepo ($monorepoFolder, base package "$monorepoBase")' : 'polyrepo'}');
  stdout.writeln('Project folder:     $outputPath');
  stdout.writeln('Project name:        $projectName');
  stdout.writeln('App name:            $appName');
  stdout.writeln('Application ID:      $applicationId (staging: $applicationId.staging)');
  stdout.writeln('Seed color:          $seedColor');
  stdout.writeln('Description:         $description');
  stdout.writeln('API (staging):       $apiStaging');
  stdout.writeln('API (production):    $apiProduction');
  stdout.writeln('iOS App Store URL:   $iosAppStoreUrl');
  stdout.writeln('Colours:            ${colorEntries == null ? 'built-in colour set' : '${colorEntries.length} from $colorsXmlPath'}');
  stdout.writeln('Fonts:               ${fontsDir ?? '(skipped)'}');
  stdout.writeln('Images:              ${imagesDir ?? '(skipped)'}');
  stdout.writeln('App icon:            ${iconPath ?? '(skipped -- placeholder icon kept)'}');
  stdout.writeln('google-services.json: $googleServicesPath');
  for (final flavor in _flavors) {
    stdout.writeln('GoogleService-Info ($flavor): ${plistPaths[flavor]}');
  }
  stdout.write(_question('\nGenerate with these values?') + _hint(' [Y/n] '));
  final confirmed = _readLine().toLowerCase();
  if (confirmed == 'n' || confirmed == 'no') {
    stdout.writeln('Cancelled.');
    exit(0);
  }

  final repoRoot = File.fromUri(Platform.script).parent.parent.path;
  final outputDir = Directory(outputPath);
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

  // Hand the colours to the brick's post_gen hook through a cleaned-up copy
  // (flutter_gen fails on duplicate names, so repeats are dropped here).
  File? colorsXml;
  if (colorEntries != null) {
    colorsXml = File('${varsFile.parent.path}/color.xml')
      ..writeAsStringSync([
        '<?xml version="1.0" encoding="utf-8"?>',
        '<resources>',
        for (final e in colorEntries.entries) '    <color name="${e.key}">#${e.value}</color>',
        '</resources>',
        '',
      ].join('\n'));
  }

  stdout.writeln('\nResolving the brick...');
  await _runInherited('mason', ['get'], workingDirectory: repoRoot);

  stdout.writeln('\nGenerating "$projectName"...');
  await _runInherited(
    'mason',
    ['make', 'app_starter', '-o', outputDir.path, '-c', varsFile.path, '--on-conflict', 'overwrite'],
    workingDirectory: repoRoot,
    // Read by the brick's post_gen hook, which uses it as the base for the
    // launcher icons (including the STAGING/DI ribbon copies).
    environment: {
      if (iconPath != null) 'APP_STARTER_ICON': File(iconPath).absolute.path,
      if (monorepoBase != null) 'APP_STARTER_MONOREPO_BASE': monorepoBase,
      if (colorsXml != null) 'APP_STARTER_COLORS_XML': colorsXml.path,
      if (fontsDir != null) 'APP_STARTER_FONTS_DIR': Directory(fontsDir).absolute.path,
      if (imagesDir != null) 'APP_STARTER_IMAGES_DIR': Directory(imagesDir).absolute.path,
    },
  );

  stdout.writeln('\nCopying google-services.json into android/app/...');
  Directory('${outputDir.path}/android/app').createSync(recursive: true);
  File(googleServicesPath).copySync('${outputDir.path}/android/app/google-services.json');

  stdout.writeln('Copying the per-flavor GoogleService-Info plists into ios/Runner/Firebase/...');
  Directory('${outputDir.path}/ios/Runner/Firebase').createSync(recursive: true);
  for (final flavor in _flavors) {
    File(plistPaths[flavor]!).copySync('${outputDir.path}/ios/Runner/Firebase/GoogleService-Info-$flavor.plist');
  }
  _writeFirebasePlistScript(outputDir.path);

  stdout.writeln('Filling the Google Sign-In keys in ios/Runner/Info.plist from the production plist...');
  _fillGoogleSignInKeys(plistPaths['production']!, '${outputDir.path}/ios/Runner/Info.plist');

  stdout.writeln('\n=== Done ===');
  stdout.writeln('"$appName" is ready at ${outputDir.path}');
  stdout.writeln('\nNext steps:');
  stdout.writeln('  cd ${outputDir.path}');
  stdout.writeln('  flutter run --flavor staging -t lib/main.dart --dart-define=FLAVOR=staging');
  stdout.writeln('\nStill manual (cannot be scripted):');
  stdout.writeln('  - Xcode: add a Run Script build phase to the Runner target (after "Compile Sources"):');
  stdout.writeln('      "\$SRCROOT/Runner/Firebase/copy_google_service_info.sh"');
  stdout.writeln('    It copies the right GoogleService-Info-<flavor>.plist into the app bundle.');
  stdout.writeln('    Also enable Push Notifications + Background Modes, upload the APNs key to Firebase.');
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
    stdout.write('${_question(prompt)}${_hint(suffix)}: ');
    final input = _readLine();
    final value = input.isEmpty ? (defaultValue ?? '') : input;

    if (value.isEmpty && required) {
      stdout.writeln(_bad('  This field is required.'));
      continue;
    }
    final error = value.isEmpty ? null : validator?.call(value);
    if (error != null) {
      stdout.writeln(_bad('  $error'));
      continue;
    }
    return value;
  }
}

String? _askOptionalFile(String label, {required List<String> extensions}) {
  while (true) {
    stdout.write('${_question(label)} ${_hint('(path, Enter to skip)')}: ');
    final input = _readLine();
    if (input.isEmpty) return null;

    final path = _expandHome(input);
    if (!File(path).existsSync()) {
      stdout.writeln(_bad('  No file found at "$path". Try again, or press Enter to skip.'));
      continue;
    }
    final lowerPath = path.toLowerCase();
    if (!extensions.any(lowerPath.endsWith)) {
      stdout.writeln(_bad('  Expected a ${extensions.join(' or ')} file. Try again, or press Enter to skip.'));
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
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
    environment: environment,
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

/// The `<base>` of an existing monorepo's `<base>_design_system` package, if
/// [root] already is a monorepo (has a melos.yaml and that package).
String? _detectMonorepoBase(Directory root) {
  final packages = Directory('${root.path}/packages');
  if (!File('${root.path}/melos.yaml').existsSync() || !packages.existsSync()) return null;
  for (final entity in packages.listSync().whereType<Directory>()) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.endsWith('_design_system')) return name.substring(0, name.length - '_design_system'.length);
  }
  return null;
}

String _askChoice(String prompt, {required List<String> choices, required String defaultValue}) {
  while (true) {
    stdout.write('${_question(prompt)} ${_hint('(${choices.join('/')}) [$defaultValue]')}: ');
    final input = _readLine().toLowerCase();
    if (input.isEmpty) return defaultValue;
    final match = choices.where((c) => c == input || c.startsWith(input)).toList();
    if (match.length == 1) return match.single;
    stdout.writeln(_bad('  Please answer ${choices.join(' or ')}.'));
  }
}

/// Reads the `<color name="x">#RRGGBB</color>` entries of a colour file into
/// name -> hex. The first definition of a repeated name wins (flutter_gen would
/// otherwise generate the same field twice and the project would not compile).
Map<String, String> _readColorEntries(String path) {
  final xml = File(path).readAsStringSync();
  final all = RegExp(r'<color\s+name="([^"]+)"[^>]*>\s*#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})\s*</color>').allMatches(xml);
  final taken = <String, String>{};
  final repeated = <String>{};
  for (final m in all) {
    final name = m.group(1)!;
    if (taken.containsKey(name)) {
      repeated.add(name);
    } else {
      taken[name] = m.group(2)!.toUpperCase();
    }
  }
  stdout.writeln('  Found ${taken.length} colours.');
  if (repeated.isNotEmpty) {
    stdout.writeln(_warn('  Warning: defined more than once (the first value is used): ${repeated.join(', ')}'));
  }
  if (taken.isEmpty) stdout.writeln(_warn('  No <color name="..">#RRGGBB</color> entries found; the built-in colours are used.'));
  return taken;
}

/// Asks for a folder that holds at least one file with one of [containing]'s
/// extensions (searched recursively). Enter skips.
String? _askOptionalDirectory(String label, {required List<String> containing}) {
  while (true) {
    stdout.write('${_question(label)} ${_hint('(path, Enter to skip)')}: ');
    final input = _readLine();
    if (input.isEmpty) return null;

    final path = _expandHome(input);
    final dir = Directory(path);
    if (!dir.existsSync()) {
      stdout.writeln(_bad('  No folder found at "$path". Try again, or press Enter to skip.'));
      continue;
    }
    final count = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => containing.any(f.path.toLowerCase().endsWith))
        .length;
    if (count == 0) {
      stdout.writeln(_bad('  No ${containing.join(' / ')} files in that folder. Try again, or press Enter to skip.'));
      continue;
    }
    stdout.writeln('  Found $count file${count == 1 ? '' : 's'}.');
    return path;
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
    stdout.write('${_question(label)} ${_hint('(path, required)')}: ');
    final input = _readLine();
    if (input.isEmpty) {
      stdout.writeln(_bad('  This file is required.'));
      continue;
    }
    final path = _expandHome(input);
    if (!File(path).existsSync()) {
      stdout.writeln(_bad('  No file found at "$path". Try again.'));
      continue;
    }
    if (!extensions.any(path.toLowerCase().endsWith)) {
      stdout.writeln(_bad('  Expected a ${extensions.join(' or ')} file. Try again.'));
      continue;
    }
    final error = validate(path);
    if (error != null) {
      stdout.writeln(_bad('  $error'));
      continue;
    }
    return path;
  }
}

/// All three flavors build from this one file, so it must list the production,
/// staging AND di packages, and Google sign-in must be enabled (a type-3 OAuth client).
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
  final missing = [production, '$production.staging', '$production.di'].where((p) => !packages.contains(p)).toList();
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

const _flavors = ['production', 'staging', 'di'];

String _bundleIdFor(String flavor, String applicationId) =>
    flavor == 'production' ? applicationId : '$applicationId.$flavor';

/// The plist must carry the Google keys and belong to this flavor's bundle id.
String? _validatePlist(String path, String expectedBundleId, String flavor) {
  final values = _readPlistStrings(path);
  for (final key in ['CLIENT_ID', 'REVERSED_CLIENT_ID', 'BUNDLE_ID']) {
    if (!values.containsKey(key)) {
      return 'GoogleService-Info.plist has no $key. Enable the Google sign-in provider in Firebase '
          'and re-download the file.';
    }
  }
  final bundleId = values['BUNDLE_ID']!;
  if (bundleId != expectedBundleId) {
    return 'BUNDLE_ID is "$bundleId" but the $flavor flavor needs "$expectedBundleId". '
        'Download the plist of the iOS app with that bundle id from Firebase.';
  }
  return null;
}

/// Build-phase helper: copies the plist matching the flavor being built into
/// the app bundle as GoogleService-Info.plist (what Firebase looks for).
void _writeFirebasePlistScript(String outputPath) {
  final script = File('$outputPath/ios/Runner/Firebase/copy_google_service_info.sh');
  script.writeAsStringSync(r'''#!/bin/sh
# Copies the GoogleService-Info plist of the flavor being built into the app bundle.
# Flavor comes from the build configuration name (e.g. Debug-staging, Release-di).
case "$CONFIGURATION" in
  *-staging) FLAVOR=staging ;;
  *-di)      FLAVOR=di ;;
  *)         FLAVOR=production ;;
esac
SRC="$SRCROOT/Runner/Firebase/GoogleService-Info-$FLAVOR.plist"
DEST="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/GoogleService-Info.plist"
if [ ! -f "$SRC" ]; then echo "error: missing $SRC"; exit 1; fi
cp "$SRC" "$DEST"
''');
  Process.runSync('chmod', ['+x', script.path]);
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
