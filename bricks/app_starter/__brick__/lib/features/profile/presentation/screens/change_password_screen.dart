import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../controllers/change_password_controller.dart';

class ChangePasswordScreen extends GetView<ChangePasswordController> {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Change password',
      body: Form(
        key: controller.formKey,
        child: ListView(
          children: [
            AppTextFormField(
              label: 'Current password',
              controller: controller.currentPasswordController,
              obscureText: true,
              validator: Validators.required('Current password'),
            ),
            const SizedBox(height: 16),
            AppTextFormField(
              label: 'New password',
              controller: controller.newPasswordController,
              obscureText: true,
              validator: Validators.password(),
            ),
            const SizedBox(height: 16),
            AppTextFormField(
              label: 'Confirm new password',
              controller: controller.confirmPasswordController,
              obscureText: true,
              validator: Validators.confirmPassword(() => controller.newPasswordController.text),
            ),
            const SizedBox(height: 24),
            Obx(
              () => AppOutlinedButton(
                label: 'Update password',
                isLoading: controller.state.value.isLoading,
                onPressed: controller.submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
