import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../session/session_service.dart';
import 'app_routes.dart';

/// Blocks logged-out users from reaching an authenticated route.
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final isLoggedIn = Get.find<SessionService>().isLoggedInSync;
    return isLoggedIn ? null : const RouteSettings(name: AppRoutes.login);
  }
}
