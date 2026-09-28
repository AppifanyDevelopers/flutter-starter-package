import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../model/profile_model.dart';

abstract class ProfileRepository {
  Future<Either<AppError, ProfileModel>> getProfile();

  Future<Either<AppError, ProfileModel>> updateProfile(ProfileModel profile);

  Future<Either<AppError, Unit>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Either<AppError, Unit>> deleteAccount();
}
