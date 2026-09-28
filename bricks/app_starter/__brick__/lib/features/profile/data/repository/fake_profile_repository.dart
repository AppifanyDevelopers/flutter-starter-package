import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../model/profile_model.dart';
import 'profile_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  ProfileModel _profile = ProfileModel.fake();

  @override
  Future<Either<AppError, ProfileModel>> getProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return right(_profile);
  }

  @override
  Future<Either<AppError, ProfileModel>> updateProfile(ProfileModel profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _profile = profile;
    return right(_profile);
  }

  @override
  Future<Either<AppError, Unit>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (currentPassword.isEmpty) {
      return left(const InternalAppError(message: 'Current password is incorrect.'));
    }
    return right(unit);
  }

  @override
  Future<Either<AppError, Unit>> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return right(unit);
  }
}
