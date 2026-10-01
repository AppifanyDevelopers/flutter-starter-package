import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/social_sign_in_buttons.dart';
import '../controllers/login_controller.dart';

class LoginScreen extends GetView<LoginController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Form(
        key: controller.formKey,
        child: ListView(
          children: [
            const SizedBox(height: 32),
            Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Sign in to continue. Demo login: demo@example.com / password123'),
            const SizedBox(height: 24),
            Obx(
              () => AppTextFormField(
                label: 'Email',
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email(),
                errorText: controller.emailError.value,
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => AppTextFormField(
                label: 'Password',
                controller: controller.passwordController,
                obscureText: controller.obscurePassword.value,
                validator: Validators.password(),
                errorText: controller.passwordError.value,
                suffixIcon: IconButton(
                  icon: Icon(controller.obscurePassword.value ? Icons.visibility_off : Icons.visibility),
                  onPressed: controller.toggleObscurePassword,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(
                  () => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: controller.rememberMe.value,
                        onChanged: (value) => controller.toggleRememberMe(value ?? false),
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(
              () => AppOutlinedButton(
                label: 'Log in',
                isLoading: controller.state.value.isLoading,
                onPressed: controller.login,
              ),
            ),
            const SizedBox(height: 24),
            SocialSignInButtons(
              onGoogleTap: controller.continueWithGoogle,
              onAppleTap: controller.continueWithApple,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: () => Get.toNamed(AppRoutes.signup),
                  child: const Text('Sign up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
