import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_envelope.dart';
import '../model/notification_item.dart';

class NotificationsPage {
  const NotificationsPage({required this.items, required this.meta});

  final List<NotificationItem> items;
  final PaginationMeta meta;
}

abstract class NotificationsRepository {
  Future<Either<AppError, NotificationsPage>> getNotifications(
      {required int page});

  Future<Either<AppError, Unit>> markAsRead(int id);
}
