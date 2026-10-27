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
  final parentPath = _expandHome(_ask(
    'Parent folder to create the project in',
    required: true,
  ));
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

  stdout.writeln(_heading('\n--- Colours ---'));
  stdout.writeln('Text, borders and status colours come from a neutral/grey/warning palette.');
  final colorsXmlPath = _askOptionalFile(
    'color.xml to take warning*, neutral* and grey* colours from (Enter to use the built-in basics)',
    extensions: ['.xml'],
  );
  final paletteOverrides = colorsXmlPath == null ? null : _readPaletteOverrides(colorsXmlPath);
  if (paletteOverrides != null && monorepo && _detectMonorepoBase(Directory('${parentDir.path}/$monorepoFolder')) != null) {
    stdout.writeln(_warn('  Note: the existing design-system package already owns the palette, so this file is ignored.'));
  }

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
  stdout.writeln('Colours:            ${paletteOverrides == null ? 'built-in basics' : '${paletteOverrides.length} from $colorsXmlPath'}');
  stdout.writeln('App icon:            ${iconPath ?? '(skipped -- placeholder icon kept)'}');
  stdout.writeln('google-services.json: $googleServicesPath');
  stdout.writeln('GoogleService-Info.plist: $googleServiceInfoPlistPath');
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

  // Hand the palette to the brick's post_gen hook through a temp file.
  File? colorsJson;
  if (paletteOverrides != null) {
    colorsJson = File('${varsFile.parent.path}/palette.json')..writeAsStringSync(jsonEncode(paletteOverrides));
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
      if (paletteOverrides != null) 'APP_STARTER_COLORS_JSON': colorsJson!.path,
    },
  );

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

/// Reads `<color name="x">#RRGGBB</color>` entries and keeps only the
/// `warning<N>`, `neutral<N>` and `grey<N>` ones. Prints what it found and
/// anything suspicious; the first definition of a repeated name wins.
Map<String, String> _readPaletteOverrides(String path) {
  final xml = File(path).readAsStringSync();
  final all = RegExp(r'<color name="([^"]+)">#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})</color>').allMatches(xml);
  final family = RegExp(r'^(warning|neutral|grey)\d+$');
  final taken = <String, String>{};
  final repeated = <String>{};
  final otherHexes = <String, String>{}; // hex -> a non-family colour that uses it
  for (final m in all) {
    final name = m.group(1)!;
    final raw = m.group(2)!;
    final hex = (raw.length == 8 ? raw.substring(2) : raw).toUpperCase();
    if (family.hasMatch(name)) {
      if (taken.containsKey(name)) {
        repeated.add(name);
      } else {
        taken[name] = hex;
      }
    } else {
      otherHexes.putIfAbsent(hex, () => name);
    }
  }
  stdout.writeln('  Using ${taken.length} colours: ${taken.keys.join(', ')}');
  if (repeated.isNotEmpty) {
    stdout.writeln(_warn('  Warning: defined more than once (the first value is used): ${repeated.join(', ')}'));
  }
  final suspicious = [
    for (final e in taken.entries)
      if (e.key.startsWith('warning') && otherHexes[e.value] != null)
        '${e.key} (#${e.value}, same as ${otherHexes[e.value]})',
  ];
  if (suspicious.isNotEmpty) {
    stdout.writeln(_warn('  Warning: these look like copy-paste mistakes (a warning colour that equals '
        'another family\'s): ${suspicious.join(', ')}'));
  }
  if (taken.isEmpty) stdout.writeln('  No warning/neutral/grey colours found; the built-in basics are used.');
  return taken;
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
  if (![production, '$production.staging', '$production.di'].contains(bundleId)) {
    return 'BUNDLE_ID is "$bundleId" but this project uses $production (production) / '
        '$production.staging (staging) / $production.di (di). Add a matching iOS app in Firebase '
        'and re-download.';
  }
  stdout.writeln(_warn('  Note: this plist is for $bundleId only. The other flavors need their own '
      'GoogleService-Info.plist (one iOS app per flavor in Firebase) before they can use Firebase.'));
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
