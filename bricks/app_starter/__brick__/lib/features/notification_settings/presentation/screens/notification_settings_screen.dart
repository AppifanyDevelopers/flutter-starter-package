import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../controllers/notification_settings_controller.dart';

class NotificationSettingsScreen extends GetView<NotificationSettingsController> {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Notification Settings',
      padding: EdgeInsets.zero,
      body: Obx(
        () => controller.state.value.showWidget(
          loading: (_) => const Center(child: AppLoadingWidget()),
          error: (_) => AppErrorWidget(message: 'Could not load settings.', onRetry: controller.retry),
          orElse: (_) => ListView.separated(
            itemCount: controller.preferences.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final preference = controller.preferences[index];
              return SwitchListTile(
                title: Text(preference.label),
                value: preference.isEnabled,
                onChanged: (value) => controller.toggle(preference, value),
              );
            },
          ),
        ),
      ),
    );
  }
}
