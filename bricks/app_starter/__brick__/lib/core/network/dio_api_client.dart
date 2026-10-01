import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_configuration.dart';
import '../errors/app_error.dart';

/// Wired up so a feature can swap its `Fake*Repository` for a real one that
/// calls through here. Unused by the fake repositories shipped by default --
/// see the `TODO(swap-backend)` markers in each feature's Bindings.
///
/// Speaks the backend envelope described in
/// `docs/ai/api-workflow/BACKEND_CONTRACT.md`: success is decided by the HTTP
/// status; errors are `{status, code, message, errors}` and become an
/// [ApiErrorResponse]. Parse a success body with `ApiEnvelope.fromJson`.
class DioApiClient {
  /// [tokenReader] supplies the current access token for `Authorization:
  /// Bearer`. [onUnauthenticated] runs once when a protected call returns
  /// `401 unauthenticated` (session ended) so the app can clear the session
  /// and show login. Both are optional so the client stays usable standalone.
  DioApiClient(
    this._dio, {
    Future<String?> Function()? tokenReader,
    Future<void> Function()? onUnauthenticated,
  }) : _onUnauthenticated = onUnauthenticated {
    _dio
      ..options.baseUrl = AppConfiguration.current.baseUrl
      ..options.connectTimeout = const Duration(seconds: 20)
      ..options.receiveTimeout = const Duration(seconds: 20)
      ..options.headers = {'Accept': 'application/json'};
    if (tokenReader != null) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await tokenReader();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
        ),
      );
    }
    _dio.interceptors.add(PrettyDioLogger(requestBody: true, responseBody: true));
  }

  final Dio _dio;
  final Future<void> Function()? _onUnauthenticated;

  Future<Either<AppError, Map<String, dynamic>>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _request(() => _dio.get(path, queryParameters: queryParameters));

  Future<Either<AppError, Map<String, dynamic>>> post(String path, {dynamic data}) =>
      _request(() => _dio.post(path, data: data));

  Future<Either<AppError, Map<String, dynamic>>> put(String path, {dynamic data}) =>
      _request(() => _dio.put(path, data: data));

  Future<Either<AppError, Map<String, dynamic>>> patch(String path, {dynamic data}) =>
      _request(() => _dio.patch(path, data: data));

  Future<Either<AppError, Map<String, dynamic>>> delete(String path, {dynamic data}) =>
      _request(() => _dio.delete(path, data: data));

  Future<Either<AppError, Map<String, dynamic>>> _request(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final response = await call();
      final data = response.data;
      return right(data is Map<String, dynamic> ? data : <String, dynamic>{'data': data});
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return left(const ConnectionError());
      }
      final error = parseError(e);
      if (error.isUnauthenticated) await _onUnauthenticated?.call();
      return left(error);
    }
  }

  /// Turns a failed response into an [ApiErrorResponse]. Non-JSON bodies
  /// (a proxy's HTML 502, say) fall back to a generic message.
  static ApiErrorResponse parseError(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;
    final retryAfter = int.tryParse(e.response?.headers.value('retry-after') ?? '');

    if (body is! Map) {
      return ApiErrorResponse(
        message: e.message ?? 'Something went wrong',
        statusCode: statusCode,
        retryAfterSeconds: retryAfter,
      );
    }

    final rawErrors = body['errors'];
    final fieldErrors = <String, List<String>>{
      if (rawErrors is Map)
        for (final entry in rawErrors.entries)
          '${entry.key}': [
            if (entry.value is List) for (final m in entry.value as List) '$m' else '${entry.value}',
          ],
    };

    return ApiErrorResponse(
      message: body['message']?.toString() ?? e.message ?? 'Something went wrong',
      statusCode: statusCode,
      code: body['code']?.toString(),
      fieldErrors: fieldErrors,
      retryAfterSeconds: retryAfter,
    );
  }
}
