import 'package:get/get.dart';

import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/session/session_service.dart';
import '../../../../core/update/app_update_service.dart';

class SplashController extends GetxController {
  final SessionService _sessionService = Get.find<SessionService>();

  @override
  void onReady() {
    super.onReady();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Minimum splash duration so the logo doesn't just flash on-screen.
    final minimumDelay = Future<void>.delayed(const Duration(milliseconds: 600));

    await _sessionService.hydrate();
    await PushNotificationService.init();

    final context = Get.context;
    if (context != null && context.mounted) {
      await AppUpdateService.checkAndPromptIfNeeded(
        context,
        iosAppStoreUrl: '{{{ios_app_store_url}}}',
        androidAppStoreUrl: 'https://play.google.com/store/apps/details?id={{application_id}}',
      );
    }

    await minimumDelay;

    final initialRoute = await PushNotificationService.consumeInitialRoute();
    Get.offAllNamed(
      initialRoute ?? (_sessionService.isLoggedInSync ? AppRoutes.dashboard : AppRoutes.login),
    );
  }
}
