import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../connectivity/connectivity_service.dart';
import '../network/dio_api_client.dart';
import '../notifications/device_token_repository.dart';
import '../routes/app_routes.dart';
import '../session/session_service.dart';
import '../theme/theme_controller.dart';

class AppInitializer {
  AppInitializer._();

  static void init() {
    final session = SessionService();
    Get
      ..put(session, permanent: true)
      ..put(ThemeController(), permanent: true)
      // TODO(swap-backend): replace with a real Dio DeviceTokenRepository.
      ..put<DeviceTokenRepository>(FakeDeviceTokenRepository(), permanent: true)
      ..put(Dio(), permanent: true)
      ..put(
        DioApiClient(
          Get.find(),
          tokenReader: session.readToken,
          onUnauthenticated: () async {
            // 401 unauthenticated = the session ended (expired, logged out,
            // or invalidated by a password reset). Only react once.
            if (!session.isLoggedInSync) return;
            await session.clear();
            Get.offAllNamed(AppRoutes.login);
          },
        ),
        permanent: true,
      );

    // Fire-and-forget: isOnline starts true and corrects itself shortly if
    // that's wrong, rather than blocking app boot on a connectivity check.
    Get.put(ConnectivityService(), permanent: true).init();
  }
}
