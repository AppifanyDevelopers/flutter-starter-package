import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/step_indicator.dart';
import '../controllers/signup_controller.dart';

/// Signup step 2 of 3: confirm the emailed code.
class SignupOtpScreen extends GetView<SignupController> {
  const SignupOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Verify your email',
      body: Form(
        key: controller.otpFormKey,
        child: ListView(
          children: [
            const StepIndicator(step: 2, totalSteps: 3, label: 'Confirm code'),
            const SizedBox(height: 16),
            Text(
              'Enter the code sent to ${controller.emailController.text.trim()}. '
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
                label: 'Continue',
                isLoading: controller.otpState.value.isLoading,
                onPressed: controller.verifyOtp,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => TextButton(
                onPressed: controller.resendState.value.isLoading ? null : controller.resendOtp,
                child: const Text('Resend code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
