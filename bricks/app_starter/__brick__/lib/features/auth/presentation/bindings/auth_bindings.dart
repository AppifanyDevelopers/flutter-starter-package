import 'package:get/get.dart';

import '../../../../core/auth/social_auth_service.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/fake_auth_repository.dart';
import '../controllers/forgot_password_controller.dart';
import '../controllers/login_controller.dart';
import '../controllers/signup_controller.dart';

class AuthBindings extends Bindings {
  @override
  void dependencies() {
    Get
      // TODO(swap-backend): replace with a real DioAuthRepository(Get.find()).
      ..lazyPut<AuthRepository>(FakeAuthRepository.new)
      ..lazyPut(() => SocialAuthService(Get.find(), Get.find()))
      ..lazyPut(() => LoginController(Get.find(), Get.find()))
      ..lazyPut(() => SignupController(Get.find(), Get.find()))
      ..lazyPut(() => ForgotPasswordController(Get.find()));
  }
}
