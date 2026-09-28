import 'package:get/get.dart';

import '../../../profile/data/repository/fake_profile_repository.dart';
import '../../../profile/data/repository/profile_repository.dart';
import '../../data/repository/fake_settings_content_repository.dart';
import '../../data/repository/settings_content_repository.dart';
import '../controllers/contact_us_controller.dart';
import '../controllers/faq_controller.dart';
import '../controllers/privacy_policy_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/terms_and_conditions_controller.dart';

class SettingsBindings extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProfileRepository>()) {
      // TODO(swap-backend): replace with a real DioProfileRepository(Get.find()).
      Get.lazyPut<ProfileRepository>(FakeProfileRepository.new, fenix: true);
    }
    Get
      // TODO(swap-backend): replace with a real DioSettingsContentRepository(Get.find()).
      ..lazyPut<SettingsContentRepository>(FakeSettingsContentRepository.new, fenix: true)
      ..lazyPut(() => SettingsController(Get.find(), Get.find()), fenix: true)
      ..lazyPut(() => FaqController(Get.find()))
      ..lazyPut(() => ContactUsController(Get.find()))
      ..lazyPut(() => TermsAndConditionsController(Get.find()))
      ..lazyPut(() => PrivacyPolicyController(Get.find()));
  }
}
