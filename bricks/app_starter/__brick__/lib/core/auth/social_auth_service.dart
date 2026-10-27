import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../features/auth/data/model/user_model.dart';
import '../../features/auth/data/repository/auth_repository.dart';
import '../errors/app_error.dart';
import '../session/session_service.dart';
import '../utils/social_auth_cancellation.dart';

/// Google/Apple sign-in, shared by `LoginController` and `SignupController`
/// (both do the exact same one-shot "continue with..." action -- see
/// docs/ARCHITECTURE.md) rather than duplicating the native-SDK-calling code
/// per screen the way rentsy_customer's reference implementation does.
///
/// Both methods return `null` if the user canceled (nothing to show) or an
/// `Either` if a real attempt happened. On success, the session is already
/// saved -- the caller just needs to navigate.
class SocialAuthService {
  SocialAuthService(this._repository, this._sessionService);

  final AuthRepository _repository;
  final SessionService _sessionService;

  Future<Either<AppError, Unit>?> continueWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return left(const InternalAppError(message: 'Google sign-in did not return a token.'));
      }

      final result = await _repository.loginWithGoogle(
        idToken: idToken,
        email: account.email,
        name: account.displayName,
      );
      return _finish(result);
    } on GoogleSignInException catch (e) {
      if (isGoogleSignInUserDismissal(e)) return null;
      return left(InternalAppError(message: e.description ?? 'Google sign-in failed.'));
    } catch (e) {
      return left(InternalAppError(message: e.toString()));
    }
  }

  Future<Either<AppError, Unit>?> continueWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: _sha256(rawNonce),
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) {
        return left(const InternalAppError(message: 'Apple sign-in did not return a token.'));
      }

      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((part) => part != null && part.isNotEmpty).join(' ');

      final result = await _repository.loginWithApple(
        identityToken: identityToken,
        email: credential.email,
        fullName: fullName.isEmpty ? null : fullName,
      );
      return _finish(result);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      return left(InternalAppError(message: e.message));
    } catch (e) {
      if (isAppleAuthorizationCanceledMessage(e.toString())) return null;
      return left(InternalAppError(message: e.toString()));
    }
  }

  Future<Either<AppError, Unit>> _finish(Either<AppError, User> result) async {
    return result.fold(
      (error) => left(error),
      (user) async {
        await _sessionService.saveSession(user.token, userId: user.id);
        return right(unit);
      },
    );
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();
}
