// Deterministic validator + router for API specs (docs/ai/api-workflow).
//
// Usage: dart scripts/api_spec.dart <spec.json> [more.json ...]
//
// No AI involved: it reads a spec, checks it for the mistakes that would
// otherwise turn into wrong generated code, and picks which template applies.
// Exit codes: 0 = routed cleanly, 1 = spec invalid, 2 = a human must decide.
// No external packages -- run directly with `dart`.

import 'dart:convert';
import 'dart:io';

const _methods = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};
const _sensitiveQueryParams = {'password', 'token', 'secret', 'otp', 'pin'};
const _mutationFields = ['confirm_before', 'on_success', 'idempotent'];
const _errorDisplays = {'snackbar', 'dialog', 'inline'};

/// Keys that mean "this call logs the user in". Deliberately exact names:
/// `reset_token` (password/verify) is a token too, but not a login.
const _authTokenKeys = {'token', 'access_token'};

class Finding {
  Finding(this.level, this.message);
  final String level; // ERROR | ASK | WARN
  final String message;
}

class Result {
  final findings = <Finding>[];
  String? template;

  void error(String m) => findings.add(Finding('ERROR', m));
  void ask(String m) => findings.add(Finding('ASK', m));
  void warn(String m) => findings.add(Finding('WARN', m));

  bool get hasErrors => findings.any((f) => f.level == 'ERROR');
  bool get needsHuman => findings.any((f) => f.level == 'ASK');
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart scripts/api_spec.dart <spec.json> [more.json ...]');
    exit(64);
  }

  var worst = 0;
  for (final path in args) {
    final result = _check(path);
    stdout.writeln('\n$path');
    stdout.writeln('  template: ${result.template ?? '(none)'}');
    for (final f in result.findings) {
      stdout.writeln('  [${f.level}] ${f.message}');
    }
    if (result.findings.isEmpty) stdout.writeln('  ok');
    if (result.hasErrors) {
      worst = 1;
    } else if (result.needsHuman && worst == 0) {
      worst = 2;
    }
  }
  exit(worst);
}

Result _check(String path) {
  final r = Result();
  final Map<String, dynamic> spec;
  try {
    final decoded = jsonDecode(File(path).readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      r.error('Spec must be a JSON object.');
      return r;
    }
    spec = decoded;
  } on FormatException catch (e) {
    r.error('Not valid JSON: ${e.message}');
    return r;
  } on FileSystemException catch (e) {
    r.error('Cannot read file: ${e.message}');
    return r;
  }

  _validate(spec, r);
  if (!r.hasErrors) r.template = _route(spec, r);
  return r;
}

void _validate(Map<String, dynamic> spec, Result r) {
  for (final key in ['name', 'endpoint', 'method', 'success_response', 'ui']) {
    if (spec[key] == null) r.error('Missing required field "$key".');
  }
  if (r.hasErrors) return;

  final method = '${spec['method']}'.toUpperCase();
  if (!_methods.contains(method)) {
    r.error('Unknown method "${spec['method']}" (expected one of ${_methods.join(', ')}).');
    return;
  }

  final params = _params(spec);
  if (method == 'GET') {
    for (final p in params) {
      final name = '${p['name']}'.toLowerCase();
      if ((p['in'] ?? 'query') == 'query' && _sensitiveQueryParams.contains(name)) {
        r.error('GET query param "$name" would put a secret in URLs and server logs. '
            'Is the method wrong (should it be POST with a body)?');
      }
    }
  }

  final errors = _errorStatuses(spec);
  if (spec['auth_required'] == true && !errors.contains(401)) {
    r.ask('auth_required is true but there is no sample 401 error response. '
        'What does the backend return for an expired/invalid token?');
  }
  final hasBodyParams = params.any((p) => p['in'] == 'body');
  if (hasBodyParams && !errors.contains(422)) {
    r.ask('$method endpoint takes a body but has no sample 422 (validation) error. '
        'Which fields can fail validation and what does the body look like?');
  }
  final e = spec['error_responses'];
  if (e is List) {
    for (final x in e) {
      if (x is Map && x['body'] is Map && (x['body'] as Map)['code'] == null) {
        r.warn('Error sample for status ${x['status']} has no "code"; the app can only branch on status.');
      }
    }
  }
  if (errors.isEmpty) r.ask('No error_responses given at all -- paste at least one real error body.');

  final ui = spec['ui'];
  if (ui is Map) {
    final display = ui['error_display'];
    if (!_errorDisplays.contains(display)) {
      r.error('ui.error_display must be one of ${_errorDisplays.join(', ')} (got "$display").');
    }
  } else {
    r.error('"ui" must be an object.');
  }

  final questions = spec['open_questions'];
  if (questions is List) {
    for (final q in questions) {
      if (q is! Map) continue;
      final text = '${q['question'] ?? ''}'.trim();
      if (text.isNotEmpty && '${q['answer'] ?? ''}'.trim().isEmpty) {
        r.ask('Unanswered open question: $text');
      }
    }
  }
  if ('${spec['task_after_success'] ?? ''}'.trim().isEmpty) {
    r.ask('task_after_success is empty. What must happen after a successful call '
        '(navigate, store, refetch, show message)? Where?');
  }
  if (spec['sample_source'] != 'real') {
    r.warn('sample_source is "${spec['sample_source'] ?? 'missing'}", not "real": '
        'generated models/parsing will only be as correct as these samples.');
  }
}

/// Decides the template. Rules run top to bottom; the first match wins.
String? _route(Map<String, dynamic> spec, Result r) {
  final method = '${spec['method']}'.toUpperCase();
  final response = spec['success_response'];
  final paramNames = _params(spec).map((p) => '${p['name']}').toSet();
  // `page` is what makes a request paginated; `per_page` is optional because
  // some backends fix the page size server-side.
  final hasPageParams = paramNames.contains('page');
  final listKey = _findList(response);
  final paginationKey = _findPagination(response);
  final hasToken = _authTokenKeys.any((k) => _hasKey(response, k));

  // 1. auth: POST that returns a token.
  if (method == 'POST' && hasToken) {
    return 'auth';
  }

  // 2. paginated_list: array + pagination object in the response.
  if (listKey != null && paginationKey != null) {
    if (method != 'GET') r.ask('Response looks paginated but method is $method; paginated lists are expected to be GET.');
    if (!hasPageParams) {
      r.ask('Response has a pagination object but the request params lack "page". '
          'Which is right?');
    } else if (!paramNames.contains('per_page')) {
      r.warn('No per_page param: page size is assumed to be fixed by the server '
          '(set ui.pagination.per_page to that value).');
    }
    final variants = spec['success_variants'];
    for (final needed in ['empty', 'last_page']) {
      if (variants is! Map || variants[needed] == null) {
        r.ask('Paginated spec needs success_variants.$needed (a real sample) '
            'to prove the empty state and "no more pages" signal.');
      }
    }
    final ui = spec['ui'] as Map;
    if (ui['pagination'] == null) {
      r.ask('Paginated response but ui.pagination is not defined (type, per_page).');
    }
    return 'paginated_list';
  }
  if (hasPageParams && method == 'GET') {
    r.ask('Request has a page param but the sample response has no list + pagination object. '
        'Is the sample incomplete?');
    return null;
  }

  // 3. simple_list: GET returning an array, no pagination.
  if (method == 'GET' && listKey != null) return 'simple_list';

  // 4. detail: GET returning a single object.
  if (method == 'GET' && response is Map) return 'detail';

  // 5. mutation: any other write. The human defines behavior via the mutation block.
  if (method != 'GET') {
    final mutation = spec['mutation'];
    if (mutation is! Map) {
      r.ask('Endpoint routes to "mutation": fill the "mutation" block '
          '(${_mutationFields.join(', ')}). The generator never guesses these.');
    } else {
      for (final f in _mutationFields) {
        if (mutation[f] == null) r.ask('mutation.$f is missing.');
      }
    }
    return 'mutation';
  }

  // 6. nothing matched.
  r.ask('No routing rule matched this spec. A human must choose a template.');
  return null;
}

List<Map<String, dynamic>> _params(Map<String, dynamic> spec) {
  final p = spec['params'];
  if (p is! List) return const [];
  return [for (final e in p) if (e is Map<String, dynamic>) e];
}

Set<int> _errorStatuses(Map<String, dynamic> spec) {
  final e = spec['error_responses'];
  if (e is! List) return {};
  return {for (final x in e) if (x is Map && x['status'] is int) x['status'] as int};
}

/// Looks for a list value at depth <= 3 (e.g. data.bookings).
String? _findList(dynamic node, [String path = '', int depth = 0]) {
  if (node is! Map || depth > 3) return null;
  for (final entry in node.entries) {
    final p = path.isEmpty ? '${entry.key}' : '$path.${entry.key}';
    if (entry.value is List) return p;
    final nested = _findList(entry.value, p, depth + 1);
    if (nested != null) return nested;
  }
  return null;
}

/// A pagination object: a map keyed "pagination"/"meta", or one that carries
/// current_page + last_page.
String? _findPagination(dynamic node, [String path = '', int depth = 0]) {
  if (node is! Map || depth > 3) return null;
  if (node.containsKey('current_page') && node.containsKey('last_page')) return path.isEmpty ? '.' : path;
  for (final entry in node.entries) {
    final p = path.isEmpty ? '${entry.key}' : '$path.${entry.key}';
    final nested = _findPagination(entry.value, p, depth + 1);
    if (nested != null) return nested;
  }
  return null;
}

bool _hasKey(dynamic node, String key, [int depth = 0]) {
  if (node is! Map || depth > 3) return false;
  if (node.containsKey(key)) return true;
  return node.values.any((v) => _hasKey(v, key, depth + 1));
}
