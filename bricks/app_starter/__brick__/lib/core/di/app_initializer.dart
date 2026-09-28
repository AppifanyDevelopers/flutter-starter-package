import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../connectivity/connectivity_service.dart';
import '../network/dio_api_client.dart';
import '../session/session_service.dart';
import '../theme/theme_controller.dart';

class AppInitializer {
  AppInitializer._();

  static void init() {
    Get
      ..put(SessionService(), permanent: true)
      ..put(ThemeController(), permanent: true)
      ..put(Dio(), permanent: true)
      ..put(DioApiClient(Get.find()), permanent: true);

    // Fire-and-forget: isOnline starts true and corrects itself shortly if
    // that's wrong, rather than blocking app boot on a connectivity check.
    Get.put(ConnectivityService(), permanent: true).init();
  }
}
