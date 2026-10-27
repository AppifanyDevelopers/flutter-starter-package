import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/password_rules_checklist.dart';
import '../../../../core/widgets/step_indicator.dart';
import '../controllers/signup_controller.dart';

/// Signup step 3 of 3: choose a password, which creates the account.
class SignupPasswordScreen extends GetView<SignupController> {
  const SignupPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Create password',
      body: Form(
        key: controller.passwordFormKey,
        child: ListView(
          children: [
            const StepIndicator(step: 3, totalSteps: 3, label: 'Password'),
            const SizedBox(height: 16),
            Obx(
              () => AppTextFormField(
                label: 'Password',
                controller: controller.passwordController,
                obscureText: controller.obscurePassword.value,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.newPassword(),
                suffixIcon: IconButton(
                  icon: Icon(controller.obscurePassword.value ? Icons.visibility_off : Icons.visibility),
                  onPressed: controller.toggleObscurePassword,
                ),
              ),
            ),
            const SizedBox(height: 8),
            PasswordRulesChecklist(controller: controller.passwordController),
            const SizedBox(height: 16),
            Obx(
              () => AppTextFormField(
                label: 'Confirm password',
                controller: controller.confirmPasswordController,
                obscureText: controller.obscurePassword.value,
                textInputAction: TextInputAction.done,
                validator: Validators.confirmPassword(() => controller.passwordController.text),
              ),
            ),
            const SizedBox(height: 24),
            Obx(
              () => AppOutlinedButton(
                label: 'Create account',
                isLoading: controller.passwordState.value.isLoading,
                onPressed: controller.createAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
