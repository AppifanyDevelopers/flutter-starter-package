import 'package:get/get.dart';

import '../../../../core/network/dio_api_client.dart';
import '../../data/repository/dio_notifications_repository.dart';
import '../../data/repository/notifications_repository.dart';
import '../controllers/notifications_controller.dart';

class NotificationsBindings extends Bindings {
  @override
  void dependencies() {
    Get
      // TODO(swap-backend): point at your own backend's repository if it differs.
      ..lazyPut<NotificationsRepository>(
        () => DioNotificationsRepository(Get.find<DioApiClient>()),
        fenix: true,
      )
      ..lazyPut(() => NotificationsController(Get.find()));
  }
}
