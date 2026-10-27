import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/social_auth_service.dart';
import '../../../../core/enums/the_states.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/session/session_service.dart';
import '../../data/repository/auth_repository.dart';

class LoginController extends GetxController {
  LoginController(this._repository, this._socialAuthService);

  final AuthRepository _repository;
  final SocialAuthService _socialAuthService;
  final SessionService _sessionService = Get.find<SessionService>();

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final obscurePassword = true.obs;
  final state = TheStates.initial.obs;
  final socialState = TheStates.initial.obs;
  late final rememberMe = (_sessionService.rememberedEmail != null).obs;

  @override
  void onInit() {
    super.onInit();
    final rememberedEmail = _sessionService.rememberedEmail;
    if (rememberedEmail != null) emailController.text = rememberedEmail;
  }

  void toggleObscurePassword() => obscurePassword.value = !obscurePassword.value;

  void toggleRememberMe(bool value) => rememberMe.value = value;

  Future<void> login() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    state.value = TheStates.loading;
    final email = emailController.text.trim();
    final result = await _repository.login(email: email, password: passwordController.text);

    await result.fold(
      (error) async {
        state.value = TheStates.error;
        Get.snackbar('Login failed', error.message);
      },
      (user) async {
        await _sessionService.saveSession(user.token, userId: user.id);
        await _sessionService.setRememberedEmail(rememberMe.value ? email : null);
        state.value = TheStates.success;
        await AnalyticsService.logLogin();
        Get.offAllNamed(AppRoutes.dashboard);
      },
    );
  }

  Future<void> continueWithGoogle() => _continueWithSocial(_socialAuthService.continueWithGoogle);

  Future<void> continueWithApple() => _continueWithSocial(_socialAuthService.continueWithApple);

  Future<void> _continueWithSocial(Future<Either<AppError, Unit>?> Function() action) async {
    if (socialState.value.isLoading) return;

    socialState.value = TheStates.loading;
    final result = await action();
    if (result == null) {
      socialState.value = TheStates.initial;
      return;
    }

    await result.fold(
      (error) async {
        socialState.value = TheStates.error;
        Get.snackbar('Sign-in failed', error.message);
      },
      (_) async {
        socialState.value = TheStates.success;
        await AnalyticsService.logLogin();
        Get.offAllNamed(AppRoutes.dashboard);
      },
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
