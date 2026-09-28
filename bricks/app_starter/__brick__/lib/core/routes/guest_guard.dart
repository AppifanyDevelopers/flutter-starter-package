import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../session/session_service.dart';
import 'app_routes.dart';

/// Skips login/signup for an already-authenticated user (e.g. after a
/// relaunch), sending them straight to the dashboard instead.
class GuestGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final isLoggedIn = Get.find<SessionService>().isLoggedInSync;
    return isLoggedIn ? const RouteSettings(name: AppRoutes.dashboard) : null;
  }
}
