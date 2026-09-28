import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../model/notification_preference.dart';

abstract class NotificationSettingsRepository {
  Future<Either<AppError, List<NotificationPreference>>> getPreferences();

  Future<Either<AppError, Unit>> updatePreference({required String key, required bool isEnabled});
}
