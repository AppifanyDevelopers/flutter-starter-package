import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/password_rules_checklist.dart';
import '../controllers/forgot_password_controller.dart';

class ResetPasswordScreen extends GetView<ForgotPasswordController> {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reset password',
      body: Form(
        key: controller.resetFormKey,
        child: ListView(
          children: [
            AppTextFormField(
              label: 'New password',
              controller: controller.newPasswordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.newPassword(),
            ),
            const SizedBox(height: 8),
            PasswordRulesChecklist(controller: controller.newPasswordController),
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
                label: 'Reset password',
                isLoading: controller.resetState.value.isLoading,
                onPressed: controller.resetPassword,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
