import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../session/session_service.dart';
import 'device_token_repository.dart';
import 'push_notification_service.dart';

/// The in-app "turn on notifications?" step shown once after a login/signup.
///
/// Explaining first and asking the OS only after "Turn on" keeps the one-shot
/// system permission dialog from being wasted. "Later" just closes it; it is
/// offered again after the next login.
abstract class PushPermissionPrompt {
  PushPermissionPrompt._();

  static Future<void> showIfPending() async {
    if (!Get.find<SessionService>().consumePushPrompt()) return;

    final turnOn = await Get.dialog<bool>(
      AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const Text('Turn on notifications?'),
        content: const Text('Get updates and reminders as they happen. You can change this any time in Settings.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Later')),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text('Turn on')),
        ],
      ),
      barrierDismissible: false,
    );
    if (turnOn != true) return;

    if (!await PushNotificationService.requestPermission()) return;
    final token = await PushNotificationService.getToken();
    if (token == null) return;
    await Get.find<DeviceTokenRepository>().register(token);
  }
}
