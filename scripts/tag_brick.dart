// Tags HEAD with the app_starter brick's version, once.
//
//   dart scripts/tag_brick.dart            # create app_starter-v<version> locally
//   dart scripts/tag_brick.dart --push     # ...and push it to origin
//   dart scripts/tag_brick.dart --dry-run  # say what would happen
//   dart scripts/tag_brick.dart --strict   # exit 2 if the brick changed under an already-tagged version
//
// The tag name comes from `bricks/app_starter/brick.yaml`, so bumping `version:`
// is the whole release step. Idempotent: if the tag already exists (locally or
// on origin) it does nothing and exits 0, so CI can run it on every push to
// main. It never moves or deletes an existing tag.
// Exit codes: 0 tagged or already tagged (including unreleased changes under an
// old version, which is normal between releases), 1 could not read the version,
// 2 with --strict only: the brick changed under an already-tagged version.
// No external packages -- run directly with `dart`.

import 'dart:io';

Future<void> main(List<String> args) async {
  final push = args.contains('--push');
  final dryRun = args.contains('--dry-run');
  final strict = args.contains('--strict');

  final brick = File('bricks/app_starter/brick.yaml');
  if (!brick.existsSync()) {
    stderr.writeln('Run this from the repo root (bricks/app_starter/brick.yaml not found).');
    exit(1);
  }
  final version = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(brick.readAsStringSync())?.group(1);
  if (version == null || !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
    stderr.writeln('Could not read a MAJOR.MINOR.PATCH version from brick.yaml (got "$version").');
    exit(1);
  }
  final tag = 'app_starter-v$version';

  final head = (await _git(['rev-parse', 'HEAD'])).trim();

  // Local tag?
  final local = (await _git(['rev-list', '-n', '1', tag], allowFail: true)).trim();
  // Remote tag? (only when an origin exists)
  var remote = '';
  final hasOrigin = (await _git(['remote'], allowFail: true)).split('\n').contains('origin');
  if (hasOrigin) {
    final out = await _git(['ls-remote', '--tags', 'origin', 'refs/tags/$tag^{}', 'refs/tags/$tag'], allowFail: true);
    // An annotated tag lists both the tag object and the commit (^{}); prefer the commit.
    final lines = out.trim().split('\n').where((l) => l.isNotEmpty).toList();
    remote = lines.where((l) => l.endsWith('^{}')).followedBy(lines).map((l) => l.split(RegExp(r'\s+')).first).firstOrNull ?? '';
  }

  final existing = local.isNotEmpty ? local : remote;
  if (existing.isNotEmpty) {
    if (existing == head) {
      stdout.writeln('$tag already exists on this commit. Nothing to do.');
      exit(0);
    }
    final where = existing.substring(0, 7);
    // Same version on main after unrelated commits is normal (docs, scripts);
    // only a *brick* change under the same version is a mistake.
    final changed = (await _git(['diff', '--name-only', existing, 'HEAD', '--', 'bricks/app_starter'], allowFail: true)).trim();
    if (changed.isEmpty) {
      stdout.writeln('$tag already exists ($where); the brick has not changed since. Nothing to do.');
      exit(0);
    }
    stdout.writeln('$tag already exists at $where, and the brick changed since:\n$changed\n'
        'Those changes are unreleased until `version:` in bricks/app_starter/brick.yaml is bumped.');
    exit(strict ? 2 : 0);
  }

  stdout.writeln('${dryRun ? '[dry run] would create' : 'Creating'} $tag at ${head.substring(0, 7)}.');
  if (dryRun) exit(0);

  await _git(['tag', '-a', tag, '-m', 'app_starter $version']);
  if (push) {
    await _git(['push', 'origin', 'refs/tags/$tag']);
    stdout.writeln('Pushed $tag.');
  } else {
    stdout.writeln('Not pushed (use --push).');
  }
}

Future<String> _git(List<String> args, {bool allowFail = false}) async {
  final result = await Process.run('git', args);
  if (result.exitCode != 0 && !allowFail) {
    stderr.writeln('git ${args.join(' ')} failed:\n${result.stderr}');
    exit(1);
  }
  return result.exitCode == 0 ? result.stdout as String : '';
}
