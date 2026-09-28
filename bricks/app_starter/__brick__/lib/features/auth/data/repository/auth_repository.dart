import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../model/user_model.dart';

abstract class AuthRepository {
  Future<Either<AppError, User>> login({required String email, required String password});

  Future<Either<AppError, User>> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    required DateTime dateOfBirth,
    String? photoPath,
  });

  /// [idToken] is Google's own ID token (not a Firebase one -- this template
  /// has no Firebase Auth dependency, see docs/ARCHITECTURE.md). A real
  /// backend verifies it server-side and creates the account if it doesn't
  /// exist yet -- the same one-shot action works for both login and signup.
  Future<Either<AppError, User>> loginWithGoogle({
    required String idToken,
    required String email,
    String? name,
  });

  /// [identityToken] is Apple's own identity token. [email]/[fullName] are
  /// only non-null on a user's *first* Apple authorization ever -- Apple
  /// doesn't send them again on later sign-ins, so a real backend must
  /// persist them then.
  Future<Either<AppError, User>> loginWithApple({
    required String identityToken,
    String? email,
    String? fullName,
  });

  /// Sends an email verification code after signup step 2 completes.
  /// Distinct from [forgotPassword] -- same OTP mechanism, different intent.
  Future<Either<AppError, Unit>> sendVerificationOtp({required String email});

  Future<Either<AppError, Unit>> forgotPassword({required String email});

  Future<Either<AppError, Unit>> verifyOtp({required String email, required String otp});

  Future<Either<AppError, Unit>> resetPassword({required String email, required String newPassword});
}
