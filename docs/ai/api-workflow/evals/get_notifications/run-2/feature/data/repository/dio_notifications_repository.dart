import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_endpoints.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/dio_api_client.dart';
import '../model/app_notification.dart';
import 'notifications_repository.dart';

class DioNotificationsRepository implements NotificationsRepository {
  DioNotificationsRepository(this._client);

  final DioApiClient _client;

  @override
  Future<Either<AppError, NotificationsPage>> getNotifications({required int page}) async {
    final result = await _client.get(AppEndpoints.notifications, queryParameters: {'page': page});
    return result.map((json) {
      final envelope = ApiEnvelope.fromJson(json);
      return NotificationsPage(
        items: envelope.dataList.map(AppNotification.fromJson).toList(),
        hasMore: envelope.meta?.hasMore ?? false,
      );
    });
  }

  @override
  Future<Either<AppError, Unit>> markAsRead(int id) async {
    final result = await _client.patch(AppEndpoints.notificationRead(id));
    return result.map((_) => unit);
  }
}
