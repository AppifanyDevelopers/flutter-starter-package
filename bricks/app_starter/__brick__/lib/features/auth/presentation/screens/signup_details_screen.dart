import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/avatar_picker.dart';
import '../../../../core/widgets/step_indicator.dart';
import '../controllers/signup_controller.dart';

class SignupDetailsScreen extends GetView<SignupController> {
  const SignupDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Personal details',
      body: Form(
        key: controller.detailsFormKey,
        child: ListView(
          children: [
            const StepIndicator(step: 2, totalSteps: 2),
            const SizedBox(height: 16),
            Center(
              child: Obx(
                () => AvatarPicker(photoPath: controller.photoPath.value, onTap: controller.pickPhoto),
              ),
            ),
            const SizedBox(height: 24),
            AppTextFormField(
              label: 'Phone number',
              controller: controller.phoneController,
              keyboardType: TextInputType.phone,
              validator: Validators.phone(),
            ),
            const SizedBox(height: 16),
            Obx(
              () => InkWell(
                onTap: () => controller.pickDateOfBirth(context),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date of birth'),
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
                label: 'Create account',
                isLoading: controller.detailsState.value.isLoading,
                onPressed: controller.submitDetails,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
