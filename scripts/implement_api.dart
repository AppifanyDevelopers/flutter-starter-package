// Orchestrates the API workflow end to end, with human gates:
//
//   spec --[gate A: validate]--> implement (headless Claude Code)
//        --[gate B: eval]--> bounded fix loop --> report --[human review]
//
// Usage:
//   dart scripts/implement_api.dart --spec get_notifications \
//       --also mark_notification_read --app /tmp/verify-app --generate
//
// Flags:
//   --spec <name>       primary spec (its .checks.json is the eval)
//   --also a,b          extra specs implemented in the same feature
//   --app <dir>         the Flutter app to change
//   --generate          create --app from the brick first (needs mason)
//   --attempts <n>      implement + fix tries before giving up (default 2)
//   --budget <usd>      per-claude-call spending cap (default 5)
//   --branch            in a git app, work on branch api/<spec>
//   --push              push that branch and print the compare URL (never
//                       merges, never touches main)
//   --dry-run           validate and print the plan, call nothing paid
//
// Deterministic steps never call a model; the only AI is the claude call.
// Exit codes: 0 passed, 1 eval failed after all attempts, 2 spec needs a
// human (open questions), 3 spec invalid, 64 bad usage, 70 tool failure.
// No external packages -- run directly with `dart`.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

final _repo = File.fromUri(Platform.script).parent.parent.path;

Future<void> main(List<String> args) async {
  final o = _parse(args);
  final spec = o['spec'];
  final appPath = o['app'];
  if (spec == null || appPath == null) {
    stderr.writeln('Usage: dart scripts/implement_api.dart --spec <name> --app <dir> '
        '[--also a,b] [--generate] [--attempts n] [--budget usd] [--branch] [--push] [--dry-run]');
    exit(64);
  }
  final also = (o['also'] ?? '').split(',').where((s) => s.isNotEmpty).toList();
  final attempts = int.tryParse(o['attempts'] ?? '') ?? 2;
  final budget = o['budget'] ?? '5';
  final dry = o.containsKey('dry-run');
  final app = Directory(appPath);

  // Gate A: every spec must validate with no open questions.
  for (final s in [spec, ...also]) {
    final v = await Process.run('dart', ['scripts/api_spec.dart', 'docs/ai/api-workflow/specs/$s.json'],
        workingDirectory: _repo);
    stdout.write(v.stdout);
    if (v.exitCode != 0) {
      stderr.writeln('\nGate A failed for "$s" (exit ${v.exitCode}): '
          '${v.exitCode == 2 ? 'a human must answer the [ASK] questions first.' : 'fix the spec.'}');
      exit(v.exitCode == 2 ? 2 : 3);
    }
  }
  if (!File('$_repo/docs/ai/api-workflow/specs/$spec.checks.json').existsSync()) {
    stderr.writeln('No $spec.checks.json: refusing to implement something that cannot be scored.');
    exit(3);
  }

  if (dry) {
    stdout.writeln('\nDRY RUN: specs are valid. Plan:');
    stdout.writeln('  app:      ${app.path}${o.containsKey('generate') ? ' (generated first)' : ''}');
    stdout.writeln('  attempts: $attempts, budget \$$budget per call');
    stdout.writeln('  prompt:\n${_indent(_implementPrompt(spec, also))}');
    exit(0);
  }

  if (o.containsKey('generate')) await _generate(app);
  if (!app.existsSync()) {
    stderr.writeln('App not found: ${app.path} (use --generate).');
    exit(64);
  }
  final inGit = Directory('${app.path}/.git').existsSync();
  final branch = 'api/$spec';
  if (inGit) {
    final dirty = await Process.run('git', ['status', '--porcelain'], workingDirectory: app.path);
    if ('${dirty.stdout}'.trim().isNotEmpty) {
      stderr.writeln('The app has uncommitted changes. Commit or stash them first so the '
          'automated change is reviewable on its own.\n${dirty.stdout}');
      exit(64);
    }
    // Keep our report out of the feature branch.
    final exclude = File('${app.path}/.git/info/exclude');
    exclude.createSync(recursive: true);
    if (!exclude.readAsStringSync().contains('api-workflow-report-')) {
      exclude.writeAsStringSync('\napi-workflow-report-*.md\n', mode: FileMode.append);
    }
  }
  if (o.containsKey('branch') && inGit) {
    await _git(app, ['checkout', '-B', branch]);
  }

  var totalCost = 0.0;
  var prompt = _implementPrompt(spec, also);
  var continuing = false;
  _Eval last = _Eval(false, '');
  var used = 0;
  for (var i = 1; i <= attempts; i++) {
    used = i;
    stdout.writeln('\n=== Attempt $i/$attempts: ${continuing ? 'fix' : 'implement'} ===');
    final r = await _claude(app, prompt, budget, continuing);
    totalCost += r.cost;
    stdout.writeln('claude: ${r.summary}');
    last = await _eval(spec, app);
    stdout.writeln(last.output);
    if (last.passed) break;
    continuing = true;
    prompt = _fixPrompt(last.failures);
  }

  final report = _report(spec, also, app, used, last, totalCost);
  File('${app.path}/api-workflow-report-$spec.md').writeAsStringSync(report);
  stdout.writeln('\nReport: ${app.path}/api-workflow-report-$spec.md');

  if (last.passed && inGit) {
    final stat = await Process.run('git', ['status', '--short'], workingDirectory: app.path);
    stdout.writeln('\nChanges for review (nothing staged yet):\n${stat.stdout}');
    if (o.containsKey('push')) {
      await _git(app, ['add', '-A']);
      await _git(app, ['commit', '-m', 'feat: implement $spec from spec (automated, needs review)']);
      await _git(app, ['push', '-u', 'origin', branch]);
      final url = (await Process.run('git', ['remote', 'get-url', 'origin'], workingDirectory: app.path))
          .stdout
          .toString()
          .trim()
          .replaceAll(RegExp(r'\.git$'), '');
      stdout.writeln('Branch pushed. Open a draft PR for review: $url/compare/$branch?expand=1');
    }
  } else if (o.containsKey('push')) {
    stdout.writeln('Not pushing: ${last.passed ? 'app is not a git repo' : 'eval did not pass'}.');
  }
  stdout.writeln(last.passed
      ? '\nPASSED. A human must still review the diff; nothing was merged.'
      : '\nFAILED after $used attempt(s). See the report; a human takes over.');
  exit(last.passed ? 0 : 1);
}

String _implementPrompt(String spec, List<String> also) {
  final all = [spec, ...also];
  final specFiles = all.map((s) => '- $_repo/docs/ai/api-workflow/specs/$s.json').join('\n');
  return '''
You are implementing backend API specs into the Flutter app in the current directory (a project generated from the app_starter brick).

Specs to implement together, as one feature:
$specFiles

Read first: $_repo/docs/ai/api-workflow/README.md, CONVENTIONS.md and BACKEND_CONTRACT.md in the same folder. Then read only the reference code those docs name inside THIS app. Follow each spec's open_questions answers, task_after_success, integration and out_of_scope exactly. Do not invent response fields absent from the spec samples.

Rules:
- Edit only this app. Do not read or open anything under $_repo/docs/ai/api-workflow/evals/ or any *.checks.json, and do not read $_repo/scripts/.
- Add controller/repository tests with a fake repository or stubbed Dio (no real network).
- Run `flutter analyze` (read the FULL output, zero issues) and `flutter test`; fix failures.
- Do not commit.
- End with a short list of every spec ambiguity you resolved by guessing.
''';
}

String _fixPrompt(String failures) => '''
An automated evaluation of your work failed these checks:

$failures

Fix exactly these problems without changing unrelated code, then re-run `flutter analyze` and `flutter test`. Do not read evals/ or *.checks.json. Do not commit. End with what you changed.
''';

class _Claude {
  _Claude(this.summary, this.cost);
  final String summary;
  final double cost;
}

Future<_Claude> _claude(Directory app, String prompt, String budget, bool cont) async {
  final cmd = <String>[
    '-p',
    prompt,
    '--output-format',
    'json',
    '--permission-mode',
    'acceptEdits',
    '--allowedTools',
    'Read,Write,Edit,Glob,Grep,Bash(flutter *),Bash(dart *),Bash(ls *)',
    '--add-dir',
    _repo,
    '--max-budget-usd',
    budget,
    if (cont) '--continue',
  ];
  final p = await Process.start('claude', cmd, workingDirectory: app.path);
  final out = StringBuffer();
  final err = StringBuffer();
  p.stdout.transform(utf8.decoder).listen(out.write);
  p.stderr.transform(utf8.decoder).listen(err.write);
  final code = await p.exitCode.timeout(const Duration(minutes: 20), onTimeout: () {
    p.kill();
    return -1;
  });
  if (code != 0) {
    stderr.writeln('claude exited $code\n$err\n$out');
    exit(70);
  }
  try {
    final j = jsonDecode(out.toString()) as Map<String, dynamic>;
    final cost = (j['total_cost_usd'] as num?)?.toDouble() ?? 0;
    final turns = j['num_turns'];
    final result = '${j['result'] ?? ''}'.trim();
    final tail = result.length > 400 ? '...${result.substring(result.length - 400)}' : result;
    return _Claude('$turns turns, \$${cost.toStringAsFixed(2)}. Final message: $tail', cost);
  } catch (_) {
    return _Claude('(could not parse claude output) ${out.toString().trim()}', 0);
  }
}

class _Eval {
  _Eval(this.passed, this.output, [this.failures = '']);
  final bool passed;
  final String output;
  final String failures;
}

Future<_Eval> _eval(String spec, Directory app) async {
  final r = await Process.run('dart', ['scripts/eval_api.dart', '--spec', spec, '--app', app.path],
      workingDirectory: _repo);
  final text = '${r.stdout}${r.stderr}';
  final failures = text.split('\n').where((l) => l.contains('FAIL') || l.startsWith('        ')).join('\n');
  return _Eval(r.exitCode == 0, text, failures);
}

Future<void> _generate(Directory app) async {
  if (app.existsSync() && app.listSync().isNotEmpty) {
    stdout.writeln('App dir not empty, skipping generate.');
    return;
  }
  app.createSync(recursive: true);
  final r = await Process.run('dart', ['scripts/eval_api.dart', '--app', app.path, '--generate-only'],
      workingDirectory: _repo);
  if (!Directory('${app.path}/lib').existsSync()) {
    stderr.writeln('Generation failed:\n${r.stdout}${r.stderr}');
    exit(70);
  }
}

Future<void> _git(Directory app, List<String> args) async {
  final r = await Process.run('git', args, workingDirectory: app.path);
  if (r.exitCode != 0) {
    stderr.writeln('git ${args.join(' ')} failed:\n${r.stderr}');
    exit(70);
  }
}

String _report(String spec, List<String> also, Directory app, int attempts, _Eval last, double cost) => '''
# API workflow report: $spec

- Result: ${last.passed ? 'PASSED' : 'FAILED'} after $attempts attempt(s)
- Specs: ${[spec, ...also].join(', ')}
- Cost (claude): \$${cost.toStringAsFixed(2)}
- Human review still required; nothing was merged.

## Eval output

```
${last.output.trim()}
```
''';

String _indent(String s) => s.split('\n').map((l) => '    $l').join('\n');

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
