import 'package:mason/mason.dart';

final _projectNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');
final _orgSegmentPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$');
final _hexColorPattern = RegExp(r'^#?([0-9a-fA-F]{6})$');

const _dartReservedWords = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default',
  'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if',
  'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', 'this',
  'throw', 'true', 'try', 'var', 'void', 'while', 'with',
};

void run(HookContext context) {
  final vars = context.vars;

  final projectName = (vars['project_name'] as String).trim();
  if (!_projectNamePattern.hasMatch(projectName) ||
      _dartReservedWords.contains(projectName)) {
    throw Exception(
      'Invalid project_name "$projectName". Must be lower_snake_case, '
      'start with a letter, contain only [a-z0-9_], and not be a Dart '
      'reserved word (e.g. acme_rentals).',
    );
  }

  final appName = (vars['app_name'] as String).trim();
  if (appName.isEmpty) {
    throw Exception('app_name must not be empty.');
  }
  // Used wherever app_name is embedded in a double-quoted Dart string
  // literal (e.g. `Text("{{{app_name_dart}}}")`) -- escapes backslashes and
  // double quotes so a name like `Bob's "Best" Diner` can't break Dart
  // syntax. Triple-mustache alone only stops Mason's HTML-entity escaping;
  // it doesn't stop the raw character from breaking the surrounding syntax.
  vars['app_name_dart'] = appName.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  final applicationId = (vars['application_id'] as String).trim();
  final idSegments = applicationId.split('.');
  if (idSegments.length < 2 ||
      idSegments.any((s) => !_orgSegmentPattern.hasMatch(s))) {
    throw Exception(
      'Invalid application_id "$applicationId". Must be reverse-DNS with at least '
      'two segments, each starting with a letter and containing only letters '
      'and digits -- no underscores or hyphens, which iOS bundle ids and '
      'Android packages reject (e.g. com.acme.rentals).',
    );
  }
  // `flutter create --org` wants the id minus its last segment.
  vars['application_id_parent'] = idSegments.sublist(0, idSegments.length - 1).join('.');

  final seedColor = (vars['seed_color'] as String).trim();
  final match = _hexColorPattern.firstMatch(seedColor);
  if (match == null) {
    throw Exception(
      'Invalid seed_color "$seedColor". Must be a 6-digit hex color, with '
      'or without a leading # (e.g. #6750A4).',
    );
  }
  vars['seed_color_hex'] = match.group(1)!.toUpperCase();

  for (final key in ['api_base_url_staging', 'api_base_url_production']) {
    final url = (vars[key] as String).trim();
    if (!url.startsWith('https://')) {
      throw Exception('Invalid $key "$url". Must start with https://.');
    }
  }

  final iosStoreUrl = (vars['ios_app_store_url'] as String).trim();
  if (!iosStoreUrl.startsWith('https://apps.apple.com/') && !iosStoreUrl.startsWith('https://itunes.apple.com/')) {
    throw Exception(
      'Invalid ios_app_store_url "$iosStoreUrl". Must be an App Store link, e.g. '
      'https://apps.apple.com/app/id1234567890.',
    );
  }

  context.logger.info(
    'Generating "$appName" ($projectName, id: $applicationId, '
    'seed color: #${vars['seed_color_hex']})...',
  );
}
