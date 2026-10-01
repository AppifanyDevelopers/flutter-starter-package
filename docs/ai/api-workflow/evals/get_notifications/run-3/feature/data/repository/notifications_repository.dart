import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../model/notification_item.dart';

abstract class NotificationsRepository {
  Future<Either<AppError, NotificationPage>> getNotifications({required int page});

  Future<Either<AppError, Unit>> markRead(int id);
}
