import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/repository/profile_repository.dart';

class ChangePasswordController extends GetxController {
  ChangePasswordController(this._repository);

  final ProfileRepository _repository;

  final formKey = GlobalKey<FormState>();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final state = TheStates.initial.obs;

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    state.value = TheStates.loading;
    final result = await _repository.changePassword(
      currentPassword: currentPasswordController.text,
      newPassword: newPasswordController.text,
    );
    result.fold(
      (error) {
        state.value = TheStates.error;
        Get.snackbar('Could not change password', error.message);
      },
      (_) {
        state.value = TheStates.success;
        AppSnackbar.success('Success', 'Your password has been changed.');
        Get.back<void>();
      },
    );
  }

  @override
  void onClose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
