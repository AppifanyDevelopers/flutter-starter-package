import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/repository/auth_repository.dart';

class ForgotPasswordController extends GetxController {
  ForgotPasswordController(this._repository);

  final AuthRepository _repository;

  final emailFormKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final emailState = TheStates.initial.obs;

  final otpFormKey = GlobalKey<FormState>();
  final otpController = TextEditingController();
  final otpState = TheStates.initial.obs;

  final resetFormKey = GlobalKey<FormState>();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final resetState = TheStates.initial.obs;

  Future<void> sendResetEmail() async {
    if (!(emailFormKey.currentState?.validate() ?? false)) return;

    emailState.value = TheStates.loading;
    final result = await _repository.forgotPassword(email: emailController.text.trim());
    result.fold(
      (error) {
        emailState.value = TheStates.error;
        Get.snackbar('Something went wrong', error.message);
      },
      (_) {
        emailState.value = TheStates.success;
        Get.toNamed(AppRoutes.forgotPasswordOtp);
      },
    );
  }

  Future<void> verifyOtp() async {
    if (!(otpFormKey.currentState?.validate() ?? false)) return;

    otpState.value = TheStates.loading;
    final result = await _repository.verifyOtp(
      email: emailController.text.trim(),
      otp: otpController.text.trim(),
    );
    result.fold(
      (error) {
        otpState.value = TheStates.error;
        Get.snackbar('Invalid code', error.message);
      },
      (_) {
        otpState.value = TheStates.success;
        Get.toNamed(AppRoutes.resetPassword);
      },
    );
  }

  Future<void> resetPassword() async {
    if (!(resetFormKey.currentState?.validate() ?? false)) return;

    resetState.value = TheStates.loading;
    final result = await _repository.resetPassword(
      email: emailController.text.trim(),
      newPassword: newPasswordController.text,
    );
    result.fold(
      (error) {
        resetState.value = TheStates.error;
        Get.snackbar('Something went wrong', error.message);
      },
      (_) {
        resetState.value = TheStates.success;
        AppSnackbar.success('Success', 'Your password has been reset. Please log in.');
        Get.offAllNamed(AppRoutes.login);
      },
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
