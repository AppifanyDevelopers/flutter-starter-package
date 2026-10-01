// Scores an implemented API feature against its spec.
//
// Usage:
//   dart scripts/eval_api.dart --spec get_notifications --app /tmp/verify-app
//   dart scripts/eval_api.dart --spec get_notifications --app /tmp/verify-app \
//       --candidate docs/ai/api-workflow/evals/get_notifications/run-1
//   dart scripts/eval_api.dart --spec get_notifications --app /tmp/verify-app --generate
//
// --app         a generated app to score (created with --generate if missing)
// --generate-only  just generate the app, no scoring (--spec not needed)
// --generate    run `mason make app_starter` into --app first (needs mason)
// --candidate   copy a saved run (feature/ + *_test.dart) into --app first
//
// Steps: 1 spec validator  2 flutter analyze  3 flutter test  4 pattern
// checks from specs/<spec>.checks.json. Exit 0 = every check passed.
// No external packages -- run directly with `dart`.

import 'dart:convert';
import 'dart:io';

const _specsDir = 'docs/ai/api-workflow/specs';

class Row {
  Row(this.name, this.passed, [this.detail = '']);
  final String name;
  final bool passed;
  final String detail;
}

Future<void> main(List<String> args) async {
  final opts = _parse(args);
  final spec = opts['spec'];
  final appPath = opts['app'];
  if (appPath == null || (spec == null && !opts.containsKey('generate-only'))) {
    stderr.writeln('Usage: dart scripts/eval_api.dart --spec <name> --app <dir> '
        '[--generate] [--candidate <run dir>]');
    exit(64);
  }
  final app = Directory(appPath);

  if (opts.containsKey('generate') || opts.containsKey('generate-only')) await _generate(app);
  if (opts.containsKey('generate-only')) exit(0);
  if (spec == null) exit(64);
  if (!app.existsSync()) {
    stderr.writeln('App not found: $appPath (pass --generate to create it).');
    exit(64);
  }
  if (opts['candidate'] != null) _installCandidate(Directory(opts['candidate']!), app);

  final rows = <Row>[];

  // 1. Spec validator: 0 routed, 2 = open questions (fail: not ready to build).
  final v = await Process.run('dart', ['scripts/api_spec.dart', '$_specsDir/$spec.json']);
  rows.add(Row('spec validates and routes', v.exitCode == 0,
      v.exitCode == 0 ? '' : '${v.stdout}'.trim()));

  // 2-3. Analyzer and tests inside the app.
  final analyze = await Process.run('flutter', ['analyze'], workingDirectory: app.path);
  rows.add(Row('flutter analyze clean', analyze.exitCode == 0,
      analyze.exitCode == 0 ? '' : _tail('${analyze.stdout}')));
  final test = await Process.run('flutter', ['test'], workingDirectory: app.path);
  rows.add(Row('flutter test passes', test.exitCode == 0,
      test.exitCode == 0 ? '' : _tail('${test.stdout}')));

  // 4. Pattern checks.
  final checksFile = File('$_specsDir/$spec.checks.json');
  if (checksFile.existsSync()) {
    final checks = (jsonDecode(checksFile.readAsStringSync()) as Map)['checks'] as List;
    for (final c in checks) {
      rows.add(_runCheck(c as Map<String, dynamic>, app));
    }
  } else {
    rows.add(Row('pattern checks defined', false, 'Missing $_specsDir/$spec.checks.json'));
  }

  _report(spec, rows);
  exit(rows.every((r) => r.passed) ? 0 : 1);
}

Map<String, String?> _parse(List<String> args) {
  final out = <String, String?>{};
  for (var i = 0; i < args.length; i++) {
    if (!args[i].startsWith('--')) continue;
    final key = args[i].substring(2);
    final hasValue = i + 1 < args.length && !args[i + 1].startsWith('--');
    out[key] = hasValue ? args[++i] : null;
  }
  return out;
}

Future<void> _generate(Directory app) async {
  if (app.existsSync() && app.listSync().isNotEmpty) {
    stdout.writeln('App dir not empty, skipping generate: ${app.path}');
    return;
  }
  app.createSync(recursive: true);
  final vars = File('${app.path}/../eval-vars.json');
  vars.writeAsStringSync(jsonEncode({
    'project_name': 'verify_app',
    'app_name': 'Verify App',
    'org': 'com.example.verify',
    'seed_color': '#1E88E5',
    'description': 'eval app',
    'api_base_url_staging': 'https://staging-api.example.com/api',
    'api_base_url_production': 'https://api.example.com/api',
  }));
  for (final cmd in [
    ['mason', 'get'],
    ['mason', 'make', 'app_starter', '-o', app.path, '-c', vars.path, '--on-conflict', 'overwrite'],
  ]) {
    stdout.writeln('> ${cmd.join(' ')}');
    final r = await Process.run(cmd.first, cmd.sublist(1));
    if (r.exitCode != 0) {
      stderr.writeln(r.stdout);
      stderr.writeln(r.stderr);
      exit(70);
    }
  }
}

/// Copies `<run>/feature` -> lib/features/<name> and `<run>/*_test.dart` -> test/,
/// rewriting the saved package name to the target app's.
void _installCandidate(Directory run, Directory app) {
  final feature = Directory('${run.path}/feature');
  if (!feature.existsSync()) {
    stderr.writeln('No feature/ folder in ${run.path}');
    exit(64);
  }
  final pubspec = File('${app.path}/pubspec.yaml').readAsStringSync();
  final pkg = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1)!;
  final name = _featureName(run);
  final dest = Directory('${app.path}/lib/features/$name');
  if (dest.existsSync()) dest.deleteSync(recursive: true);

  void copy(File from, String to) {
    File(to).parent.createSync(recursive: true);
    File(to).writeAsStringSync(from.readAsStringSync().replaceAll('package:verify_app/', 'package:$pkg/'));
  }

  for (final f in feature.listSync(recursive: true).whereType<File>()) {
    final rel = f.path.substring(feature.path.length + 1);
    copy(f, '${dest.path}/$rel');
  }
  for (final f in run.listSync().whereType<File>().where((f) => f.path.endsWith('_test.dart'))) {
    copy(f, '${app.path}/test/${f.uri.pathSegments.last}');
  }
  stdout.writeln('Installed candidate from ${run.path} as features/$name');
}

/// Saved runs live at evals/<spec>/run-N; the feature folder name comes from
/// its own layout (its first import path), falling back to the spec name.
String _featureName(Directory run) {
  final ctl = Directory('${run.path}/feature/presentation/controllers');
  if (ctl.existsSync()) {
    final f = ctl.listSync().whereType<File>().first.uri.pathSegments.last;
    return f.replaceAll('_controller.dart', '');
  }
  return 'candidate';
}

/// Name-agnostic: finds the method wired to `onRefresh:` in the screen and
/// requires that its body in the controller never sets the loading state.
Row _refreshHandlerCheck(Map<String, dynamic> c, Directory app) {
  final id = '${c['id']}';
  final dir = Directory('${app.path}/${c['dir']}');
  if (!dir.existsSync()) return Row(id, false, 'dir ${c['dir']} not found');
  String read(String part) => dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && f.path.substring(dir.path.length).contains(part))
      .map((f) => f.readAsStringSync())
      .join('\n');
  final screen = read('screen');
  final controller = read('controller');
  final handler = RegExp(r'onRefresh:\s*(?:controller\.)?(\w+)').firstMatch(screen)?.group(1);
  if (handler == null) return Row(id, false, 'no onRefresh handler found in the screen');
  final body = RegExp('Future<void>\\s+$handler\\(\\)\\s*async\\s*\\{((?:(?!\\n  \\}\\n)[\\s\\S])*)')
      .firstMatch(controller)
      ?.group(1);
  if (body == null) return Row(id, false, 'handler "$handler" not found in the controller');
  if (body.contains('TheStates.loading')) {
    return Row(id, false, '$handler() sets TheStates.loading (shimmer replaces the list mid-refresh)');
  }
  return Row('${c['description'] ?? id}', true);
}

Row _runCheck(Map<String, dynamic> c, Directory app) {
  if (c['kind'] == 'refresh_handler') return _refreshHandlerCheck(c, app);
  final id = '${c['id']}';
  final dir = Directory('${app.path}/${c['dir']}');
  if (!dir.existsSync()) return Row(id, false, 'dir ${c['dir']} not found');
  final includes = [for (final i in (c['includes'] as List? ?? const [])) '$i'];
  final text = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) {
        // Match against the path inside the checked dir, never the app path.
        final rel = f.path.substring(dir.path.length);
        return includes.isEmpty || includes.any(rel.contains);
      })
      .map((f) => f.readAsStringSync())
      .join('\n');
  if (text.isEmpty) return Row(id, false, 'no files matched includes $includes');

  for (final p in (c['must_match'] as List? ?? const [])) {
    if (!RegExp('$p', multiLine: true).hasMatch(text)) return Row(id, false, 'missing: $p');
  }
  for (final p in (c['must_not_match'] as List? ?? const [])) {
    final m = RegExp('$p', multiLine: true).firstMatch(text);
    if (m != null) return Row(id, false, 'forbidden: $p -> "${m.group(0)!.trim()}"');
  }
  return Row('${c['description'] ?? id}', true);
}

String _tail(String s) {
  final lines = s.split(RegExp(r'[\r\n]+')).where((l) => l.trim().isNotEmpty).toList();
  return lines.skip(lines.length > 8 ? lines.length - 8 : 0).join('\n');
}

void _report(String spec, List<Row> rows) {
  stdout.writeln('\nEval: $spec');
  for (final r in rows) {
    stdout.writeln('  ${r.passed ? 'PASS' : 'FAIL'}  ${r.name}');
    if (!r.passed && r.detail.isNotEmpty) {
      for (final line in r.detail.split('\n')) {
        stdout.writeln('        $line');
      }
    }
  }
  final failed = rows.where((r) => !r.passed).length;
  stdout.writeln('\n${rows.length - failed}/${rows.length} passed');
}
