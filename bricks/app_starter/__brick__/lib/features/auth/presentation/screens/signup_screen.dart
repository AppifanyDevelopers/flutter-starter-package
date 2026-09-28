import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/social_sign_in_buttons.dart';
import '../../../../core/widgets/step_indicator.dart';
import '../controllers/signup_controller.dart';

class SignupScreen extends GetView<SignupController> {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Create account',
      body: Form(
        key: controller.formKey,
        child: ListView(
          children: [
            const StepIndicator(step: 1, totalSteps: 2),
            const SizedBox(height: 16),
            AppTextFormField(
              label: 'Full name',
              controller: controller.nameController,
              validator: Validators.required('Name'),
            ),
            const SizedBox(height: 16),
            AppTextFormField(
              label: 'Email',
              controller: controller.emailController,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email(),
            ),
            const SizedBox(height: 16),
            Obx(
              () => AppTextFormField(
                label: 'Password',
                controller: controller.passwordController,
                obscureText: controller.obscurePassword.value,
                validator: Validators.password(),
                suffixIcon: IconButton(
                  icon: Icon(controller.obscurePassword.value ? Icons.visibility_off : Icons.visibility),
                  onPressed: controller.toggleObscurePassword,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => AppTextFormField(
                label: 'Confirm password',
                controller: controller.confirmPasswordController,
                obscureText: controller.obscurePassword.value,
                validator: Validators.confirmPassword(() => controller.passwordController.text),
              ),
            ),
            const SizedBox(height: 24),
            AppOutlinedButton(label: 'Next', onPressed: controller.goToDetails),
            const SizedBox(height: 24),
            SocialSignInButtons(
              onGoogleTap: controller.continueWithGoogle,
              onAppleTap: controller.continueWithApple,
            ),
          ],
        ),
      ),
    );
  }
}
