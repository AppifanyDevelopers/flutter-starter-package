import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../controllers/forgot_password_controller.dart';

class ForgotPasswordOtpScreen extends GetView<ForgotPasswordController> {
  const ForgotPasswordOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Verify code',
      body: Form(
        key: controller.otpFormKey,
        child: ListView(
        children: [
          Text(
            'Enter the code sent to ${controller.emailController.text}. '
            '(Fake backend: use 1234.)',
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            label: 'Verification code',
            controller: controller.otpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            validator: Validators.otp(),
          ),
          const SizedBox(height: 24),
          Obx(
            () => AppOutlinedButton(
              label: 'Verify',
              isLoading: controller.otpState.value.isLoading,
              onPressed: controller.verifyOtp,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
