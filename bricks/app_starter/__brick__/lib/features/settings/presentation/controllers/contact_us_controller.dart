import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/repository/settings_content_repository.dart';

class ContactUsController extends GetxController {
  ContactUsController(this._repository);

  final SettingsContentRepository _repository;

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final messageController = TextEditingController();
  final state = TheStates.initial.obs;

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    state.value = TheStates.loading;
    final result = await _repository.submitContactMessage(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      message: messageController.text.trim(),
    );
    result.fold(
      (error) {
        state.value = TheStates.error;
        Get.snackbar('Could not send message', error.message);
      },
      (_) {
        state.value = TheStates.success;
        AppSnackbar.success('Thanks!', 'Your message has been sent.');
        Get.back<void>();
      },
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    messageController.dispose();
    super.onClose();
  }
}
