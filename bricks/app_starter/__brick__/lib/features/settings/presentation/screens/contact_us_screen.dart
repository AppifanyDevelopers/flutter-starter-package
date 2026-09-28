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
            AppTextFormField(
              label: 'Name',
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
            TextFormField(
              controller: controller.messageController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Message'),
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
