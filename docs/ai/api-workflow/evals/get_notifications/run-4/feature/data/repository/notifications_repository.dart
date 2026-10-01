import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../model/app_notification.dart';

abstract class NotificationsRepository {
  /// Page size is fixed at 20 by the server.
  Future<Either<AppError, NotificationsPage>> getNotifications({required int page});

  Future<Either<AppError, Unit>> markRead(int id);
}
