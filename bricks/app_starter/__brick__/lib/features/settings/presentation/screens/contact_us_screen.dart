import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/app_outlined_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../controllers/contact_us_controller.dart';

class ContactUsScreen extends GetView<ContactUsController> {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Contact us',
      body: Form(
        key: controller.formKey,
        child: ListView(
          children: [
            AppTextFormField.name(
              label: 'Name',
              controller: controller.nameController,
              validator: Validators.name(),
            ),
            const SizedBox(height: 16),
            AppTextFormField.email(
              controller: controller.emailController,
              validator: Validators.email(),
            ),
            const SizedBox(height: 16),
            AppTextFormField(
              label: 'Message',
              controller: controller.messageController,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              validator: Validators.required('Message'),
            ),
            const SizedBox(height: 24),
            Obx(
              () => AppOutlinedButton(
                label: 'Send message',
                isLoading: controller.state.value.isLoading,
                onPressed: controller.submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
