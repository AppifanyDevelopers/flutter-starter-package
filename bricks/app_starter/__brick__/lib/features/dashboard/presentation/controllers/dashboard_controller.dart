import 'package:get/get.dart';

import '../../../../core/notifications/push_permission_prompt.dart';

class DashboardController extends GetxController {
  final currentIndex = 0.obs;

  @override
  void onReady() {
    super.onReady();
    // Right after login/signup: explain, then ask for notification permission.
    PushPermissionPrompt.showIfPending();
  }

  void changeTab(int index) => currentIndex.value = index;
}
