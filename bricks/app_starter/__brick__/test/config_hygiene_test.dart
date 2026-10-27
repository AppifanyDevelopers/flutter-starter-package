import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:{{project_name}}/core/build_variants/flavor_resolver.dart';
import 'package:{{project_name}}/core/config/app_secrets.dart';

void main() {
  group('.env files are bundled into the app, so they hold no secrets', () {
    final envFiles = ['.env.staging', '.env.di', '.env.production', '.env.example'];

    test('they only contain the allow-listed non-secret keys', () {
      const allowed = {'API_BASE_URL'};
      for (final path in envFiles) {
        final keys = File(path)
            .readAsLinesSync()
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('#'))
            .map((l) => l.split('=').first);
        expect(keys.toSet().difference(allowed), isEmpty, reason: '$path has keys that must be dart-defines');
      }
    });

    test('every flavor has an env file and a dart_defines example', () {
      for (final flavor in ['staging', 'di', 'production']) {
        expect(File('.env.$flavor').existsSync(), isTrue, reason: flavor);
        expect(File('dart_defines/$flavor.json.example').existsSync(), isTrue, reason: flavor);
      }
    });
  });

  test('real dart_defines files are git-ignored, the examples are not', () {
    final ignore = File('.gitignore').readAsStringSync();
    expect(ignore, contains('dart_defines/*.json'));
    expect(ignore, contains('!dart_defines/*.json.example'));
  });

  test('secrets default to empty, so a missing define is detectable', () {
    expect(AppSecrets.apiKey, isEmpty);
    expect(AppSecrets.isConfigured, isFalse);
  });

  group('flavor resolution', () {
    test('an explicit FLAVOR define wins over --flavor', () {
      expect(resolveFlavorName(explicit: 'di', platformFlavor: 'production'), 'di');
    });
    test('--flavor decides when there is no define', () {
      expect(resolveFlavorName(explicit: '', platformFlavor: 'production'), 'production');
      expect(resolveFlavorName(explicit: '', platformFlavor: 'di'), 'di');
    });
    test('plain flutter run falls back to staging, never production', () {
      expect(resolveFlavorName(explicit: '', platformFlavor: null), 'staging');
      expect(resolveFlavorName(explicit: '', platformFlavor: ''), 'staging');
    });
  });
}
