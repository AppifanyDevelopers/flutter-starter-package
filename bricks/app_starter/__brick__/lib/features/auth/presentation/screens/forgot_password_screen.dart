import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../controllers/forgot_password_controller.dart';

class ForgotPasswordScreen extends GetView<ForgotPasswordController> {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Forgot password',
      body: Form(
        key: controller.emailFormKey,
        child: ListView(
          children: [
            const Text('Enter your email and we\'ll send you a verification code.'),
            const SizedBox(height: 16),
            AppTextFormField.email(
              controller: controller.emailController,
              textInputAction: TextInputAction.done,
              validator: Validators.email(),
            ),
            const SizedBox(height: 24),
            Obx(
              () => AppOutlinedButton(
                label: 'Send code',
                isLoading: controller.emailState.value.isLoading,
                onPressed: controller.sendResetEmail,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
