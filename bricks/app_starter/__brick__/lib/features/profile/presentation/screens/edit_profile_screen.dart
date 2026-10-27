import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/avatar_picker.dart';
import '../controllers/edit_profile_controller.dart';

class EditProfileScreen extends GetView<EditProfileController> {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Edit profile',
      body: Obx(
        () => controller.loadState.value.showWidget(
          loading: (_) => const _EditProfileShimmer(),
          error: (_) => const AppErrorWidget(message: 'Could not load your profile.'),
          orElse: (_) => Form(
            key: controller.formKey,
            child: ListView(
              children: [
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
                  label: 'Phone (optional)',
                  controller: controller.phoneController,
                  textInputAction: TextInputAction.done,
                  validator: Validators.optionalPhone(),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => InkWell(
                    onTap: () => controller.pickDateOfBirth(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date of birth (optional)'),
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
                    label: 'Save changes',
                    isLoading: controller.saveState.value.isLoading,
                    onPressed: controller.save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileShimmer extends StatelessWidget {
  const _EditProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Center(child: AppShimmer.circle(size: 96)),
        const SizedBox(height: 24),
        for (var i = 0; i < 4; i++) ...[
          AppShimmer.box(height: 48),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
