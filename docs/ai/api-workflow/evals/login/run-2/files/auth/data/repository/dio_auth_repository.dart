import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_endpoints.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/dio_api_client.dart';
import '../model/user_model.dart';
import 'auth_repository.dart';
import 'fake_auth_repository.dart';

/// Real backend for [login]; every other method still delegates to
/// [FakeAuthRepository] until its own spec is implemented.
class DioAuthRepository implements AuthRepository {
  // TODO(swap-backend): replace the delegate with real calls as specs land.
  DioAuthRepository(this._client, [AuthRepository? fallback]) : _fallback = fallback ?? FakeAuthRepository();

  final DioApiClient _client;
  final AuthRepository _fallback;

  @override
  Future<Either<AppError, User>> login({required String email, required String password}) async {
    final result = await _client.post(
      AppEndpoints.login,
      data: {'email': email.trim().toLowerCase(), 'password': password},
    );
    return result.flatMap((body) {
      final data = ApiEnvelope.fromJson(body).dataMap;
      final token = data?['access_token'];
      final user = data?['user'];
      if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
        return left(const InternalAppError(message: 'Unexpected response from the server.'));
      }
      return right(
        User(
          id: '${user['id']}',
          name: user['name'] as String? ?? '',
          email: user['email'] as String? ?? '',
          token: token,
        ),
      );
    });
  }

  @override
  Future<Either<AppError, User>> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    required DateTime dateOfBirth,
    String? photoPath,
  }) =>
      _fallback.signup(
        name: name,
        email: email,
        password: password,
        phone: phone,
        dateOfBirth: dateOfBirth,
        photoPath: photoPath,
      );

  @override
  Future<Either<AppError, User>> loginWithGoogle({
    required String idToken,
    required String email,
    String? name,
  }) =>
      _fallback.loginWithGoogle(idToken: idToken, email: email, name: name);

  @override
  Future<Either<AppError, User>> loginWithApple({
    required String identityToken,
    String? email,
    String? fullName,
  }) =>
      _fallback.loginWithApple(identityToken: identityToken, email: email, fullName: fullName);

  @override
  Future<Either<AppError, Unit>> sendVerificationOtp({required String email}) =>
      _fallback.sendVerificationOtp(email: email);

  @override
  Future<Either<AppError, Unit>> forgotPassword({required String email}) =>
      _fallback.forgotPassword(email: email);

  @override
  Future<Either<AppError, Unit>> verifyOtp({required String email, required String otp}) =>
      _fallback.verifyOtp(email: email, otp: otp);

  @override
  Future<Either<AppError, Unit>> resetPassword({required String email, required String newPassword}) =>
      _fallback.resetPassword(email: email, newPassword: newPassword);
}
