import 'package:get/get.dart';

import '../../data/repository/fake_profile_repository.dart';
import '../../data/repository/profile_repository.dart';
import '../controllers/change_password_controller.dart';
import '../controllers/edit_profile_controller.dart';

class ProfileBindings extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProfileRepository>()) {
      // TODO(swap-backend): replace with a real DioProfileRepository(Get.find()).
      Get.lazyPut<ProfileRepository>(FakeProfileRepository.new, fenix: true);
    }
    Get
      ..lazyPut(() => EditProfileController(Get.find()))
      ..lazyPut(() => ChangePasswordController(Get.find()));
  }
}
