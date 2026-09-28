import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_configuration.dart';
import '../errors/app_error.dart';

/// Wired up so a feature can swap its `Fake*Repository` for a real one that
/// calls through here. Unused by the fake repositories shipped by default --
/// see the `TODO(swap-backend)` markers in each feature's Bindings.
class DioApiClient {
  DioApiClient(this._dio) {
    _dio
      ..options.baseUrl = AppConfiguration.current.baseUrl
      ..options.connectTimeout = const Duration(seconds: 20)
      ..options.receiveTimeout = const Duration(seconds: 20)
      ..options.headers = {'Accept': 'application/json'}
      ..interceptors.add(PrettyDioLogger(requestBody: true, responseBody: true));
  }

  final Dio _dio;

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
      final responseData = e.response?.data;
      final message = responseData is Map && responseData['message'] != null
          ? responseData['message'].toString()
          : e.message ?? 'Something went wrong';
      return left(ApiErrorResponse(message: message, statusCode: e.response?.statusCode));
    }
  }
}
