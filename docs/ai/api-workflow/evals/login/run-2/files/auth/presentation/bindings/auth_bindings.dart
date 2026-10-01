import 'package:get/get.dart';

import '../../../../core/auth/social_auth_service.dart';
import '../../../../core/network/dio_api_client.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/dio_auth_repository.dart';
import '../controllers/forgot_password_controller.dart';
import '../controllers/login_controller.dart';
import '../controllers/signup_controller.dart';

class AuthBindings extends Bindings {
  @override
  void dependencies() {
    Get
      // TODO(swap-backend): DioAuthRepository only implements login; the rest still delegates to the fake.
      ..lazyPut<AuthRepository>(() => DioAuthRepository(Get.find<DioApiClient>()))
      ..lazyPut(() => SocialAuthService(Get.find(), Get.find()))
      ..lazyPut(() => LoginController(Get.find(), Get.find()))
      ..lazyPut(() => SignupController(Get.find(), Get.find()))
      ..lazyPut(() => ForgotPasswordController(Get.find()));
  }
}
