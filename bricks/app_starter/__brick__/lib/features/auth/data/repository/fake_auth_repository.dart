import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../model/user_model.dart';
import 'auth_repository.dart';

const demoEmail = 'demo@example.com';
const demoPassword = 'password123';

class FakeAuthRepository implements AuthRepository {
  final _registeredEmails = <String>{demoEmail};

  @override
  Future<Either<AppError, User>> login({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (email.toLowerCase() == demoEmail && password == demoPassword) {
      return right(User.fake());
    }
    return left(const InternalAppError(message: 'Invalid email or password.'));
  }

  @override
  Future<Either<AppError, User>> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    required DateTime dateOfBirth,
    required String verificationToken,
    String? photoPath,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (verificationToken.isEmpty) {
      return left(const InternalAppError(message: 'Email not verified.'));
    }
    final normalized = email.toLowerCase();
    if (_registeredEmails.contains(normalized)) {
      return left(const InternalAppError(message: 'An account with this email already exists.'));
    }
    _registeredEmails.add(normalized);
    // phone/dateOfBirth/photoPath are accepted here the way a real signup
    // endpoint would, but this fake backend doesn't persist them anywhere --
    // see ProfileRepository for the (separately) fake-backed profile data.
    return right(User.fake(name: name, email: email));
  }

  @override
  Future<Either<AppError, User>> loginWithGoogle({
    required String idToken,
    required String email,
    String? name,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _registeredEmails.add(email.toLowerCase());
    return right(User.fake(name: name, email: email));
  }

  @override
  Future<Either<AppError, User>> loginWithApple({
    required String identityToken,
    String? email,
    String? fullName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (email != null) _registeredEmails.add(email.toLowerCase());
    return right(User.fake(name: fullName, email: email));
  }

  @override
  Future<Either<AppError, Unit>> sendVerificationOtp({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return right(unit);
  }

  @override
  Future<Either<AppError, String>> verifySignupOtp({required String email, required String otp}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (otp != '1234') {
      return left(const InternalAppError(message: 'Invalid or expired code.'));
    }
    return right('fake-verification-token');
  }

  @override
  Future<Either<AppError, Unit>> forgotPassword({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return right(unit);
  }

  @override
  Future<Either<AppError, Unit>> verifyOtp({required String email, required String otp}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (otp != '1234') {
      return left(const InternalAppError(message: 'Invalid or expired code.'));
    }
    return right(unit);
  }

  @override
  Future<Either<AppError, Unit>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return right(unit);
  }
}
