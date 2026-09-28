import 'package:get/get.dart';

import '../../data/repository/fake_notification_settings_repository.dart';
import '../../data/repository/notification_settings_repository.dart';
import '../controllers/notification_settings_controller.dart';

class NotificationSettingsBindings extends Bindings {
  @override
  void dependencies() {
    Get
      // TODO(swap-backend): replace with a real DioNotificationSettingsRepository(Get.find()).
      ..lazyPut<NotificationSettingsRepository>(FakeNotificationSettingsRepository.new)
      ..lazyPut(() => NotificationSettingsController(Get.find()));
  }
}
