import 'package:get/get.dart';

import '../../data/repository/dio_notifications_repository.dart';
import '../../data/repository/notifications_repository.dart';
import '../controllers/notifications_controller.dart';

class NotificationsBindings extends Bindings {
  @override
  void dependencies() {
    Get
      // Real Dio repository (the reference backend has these endpoints).
      ..lazyPut<NotificationsRepository>(() => DioNotificationsRepository(Get.find()))
      ..lazyPut(() => NotificationsController(Get.find()));
  }
}
