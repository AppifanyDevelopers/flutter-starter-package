import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_endpoints.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/dio_api_client.dart';
import '../model/notification_item.dart';
import 'notifications_repository.dart';

class DioNotificationsRepository implements NotificationsRepository {
  DioNotificationsRepository(this._client);

  final DioApiClient _client;

  @override
  Future<Either<AppError, NotificationPage>> getNotifications({required int page}) async {
    final result = await _client.get(AppEndpoints.notifications, queryParameters: {'page': page});
    return result.map((json) {
      final envelope = ApiEnvelope.fromJson(json);
      return NotificationPage(
        items: envelope.dataList.map(NotificationItem.fromJson).toList(),
        hasMore: envelope.meta?.hasMore ?? false,
      );
    });
  }

  @override
  Future<Either<AppError, Unit>> markRead(int id) async {
    final result = await _client.patch(AppEndpoints.notificationRead(id));
    return result.map((_) => unit);
  }
}
