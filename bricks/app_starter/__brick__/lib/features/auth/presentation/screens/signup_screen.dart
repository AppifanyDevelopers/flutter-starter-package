import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/avatar_picker.dart';
import '../../../../core/widgets/social_sign_in_buttons.dart';
import '../../../../core/widgets/step_indicator.dart';
import '../controllers/signup_controller.dart';

/// Signup step 1 of 3: basic details.
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
            const StepIndicator(step: 1, totalSteps: 3, label: 'Basic details'),
            const SizedBox(height: 16),
            Center(
              child: Obx(
                () => AvatarPicker(photoPath: controller.photoPath.value, onTap: controller.pickPhoto),
              ),
            ),
            const SizedBox(height: 24),
            AppTextFormField.name(
              controller: controller.nameController,
              validator: Validators.name(),
            ),
            const SizedBox(height: 16),
            AppTextFormField.email(
              controller: controller.emailController,
              validator: Validators.email(),
            ),
            const SizedBox(height: 16),
            AppTextFormField.phone(
              controller: controller.phoneController,
              validator: Validators.phone(),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            Obx(
              () => InkWell(
                onTap: () => controller.pickDateOfBirth(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of birth',
                    errorText: controller.dobError.value,
                  ),
                  child: Text(
                    controller.dateOfBirth.value == null
                        ? 'Select date'
                        : formatDate(controller.dateOfBirth.value!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Obx(
              () => AppOutlinedButton(
                label: 'Continue',
                isLoading: controller.detailsState.value.isLoading,
                onPressed: controller.submitDetails,
              ),
            ),
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
