import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{project_name}}/core/network/api_envelope.dart';
import 'package:{{project_name}}/core/network/dio_api_client.dart';

DioException _err(int status, dynamic body, {Map<String, List<String>>? headers}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: body, headers: Headers.fromMap(headers ?? {})),
  );
}

void main() {
  test('422 validation keeps code and field errors', () {
    final e = DioApiClient.parseError(_err(422, {
      'status': 422, 'code': 'validation_failed', 'message': 'The email field is required. (and 1 more error)',
      'errors': {'email': ['The email field is required.'], 'password': ['The password field is required.']},
    }));
    expect(e.code, 'validation_failed');
    expect(e.firstError('email'), 'The email field is required.');
    expect(e.firstError('nope'), isNull);
    expect(e.isValidationFailed, isTrue);
  });

  test('401 unauthenticated vs invalid_credentials', () {
    final a = DioApiClient.parseError(_err(401, {'status': 401, 'code': 'unauthenticated', 'message': 'Unauthenticated.', 'errors': null}));
    final b = DioApiClient.parseError(_err(401, {'status': 401, 'code': 'invalid_credentials', 'message': 'Invalid email or password.', 'errors': null}));
    expect(a.isUnauthenticated, isTrue);
    expect(b.isUnauthenticated, isFalse);
    expect(b.fieldErrors, isEmpty);
  });

  test('429 reads Retry-After', () {
    final e = DioApiClient.parseError(_err(429, {'status': 429, 'code': 'too_many_requests', 'message': 'Too many attempts.', 'errors': null}, headers: {'retry-after': ['3600']}));
    expect(e.retryAfterSeconds, 3600);
    expect(e.isRateLimited, isTrue);
  });

  test('non-JSON body falls back', () {
    final e = DioApiClient.parseError(_err(502, '<html>bad gateway</html>'));
    expect(e.statusCode, 502);
    expect(e.code, isNull);
  });

  test('envelope: paginated, empty and last page', () {
    final page1 = ApiEnvelope.fromJson({'status': 200, 'message': 'ok', 'data': [{'id': 1}], 'meta': {'current_page': 1, 'last_page': 2, 'per_page': 20, 'total': 22, 'from': 1, 'to': 20}});
    expect(page1.meta!.hasMore, isTrue);
    expect(page1.dataList.length, 1);
    final last = ApiEnvelope.fromJson({'status': 200, 'data': [], 'meta': {'current_page': 2, 'last_page': 2, 'per_page': 20, 'total': 22, 'from': 21, 'to': 22}});
    expect(last.meta!.hasMore, isFalse);
    final empty = ApiEnvelope.fromJson({'status': 200, 'data': [], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 0, 'from': null, 'to': null}});
    expect(empty.dataList, isEmpty);
    expect(empty.meta!.from, isNull);
    final plain = ApiEnvelope.fromJson({'status': 200, 'message': null, 'data': null});
    expect(plain.dataMap, isNull);
    expect(plain.meta, isNull);
  });
}
