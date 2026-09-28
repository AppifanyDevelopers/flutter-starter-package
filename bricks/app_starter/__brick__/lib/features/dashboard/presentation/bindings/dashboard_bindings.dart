import 'package:get/get.dart';

import '../../../home/presentation/bindings/home_bindings.dart';
import '../../../settings/presentation/bindings/settings_bindings.dart';
import '../controllers/dashboard_controller.dart';

class DashboardBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(DashboardController.new);
    // The dashboard's tabs are embedded (IndexedStack), not routed, so their
    // dependencies are wired up here rather than via a GetPage binding.
    HomeBindings().dependencies();
    SettingsBindings().dependencies();
  }
}
