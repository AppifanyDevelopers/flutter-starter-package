import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/session/session_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../profile/data/repository/profile_repository.dart';
import '../../data/model/settings_item.dart';

class SettingsController extends GetxController {
  SettingsController(this._profileRepository, this._sessionService);

  final ProfileRepository _profileRepository;
  final SessionService _sessionService;
  final ThemeController _themeController = Get.find<ThemeController>();

  final isDeletingAccount = false.obs;

  List<SettingsItem> items(BuildContext context) => [
        SettingsItem(
          icon: Icons.dark_mode_outlined,
          label: 'Appearance',
          onTap: () => _showAppearanceSheet(context),
        ),
        SettingsItem(
          icon: Icons.help_outline,
          label: 'FAQ',
          onTap: () => Get.toNamed(AppRoutes.faq),
        ),
        SettingsItem(
          icon: Icons.mail_outline,
          label: 'Contact Us',
          onTap: () => Get.toNamed(AppRoutes.contactUs),
        ),
        SettingsItem(
          icon: Icons.description_outlined,
          label: 'Terms & Conditions',
          onTap: () => Get.toNamed(AppRoutes.termsAndConditions),
        ),
        SettingsItem(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () => Get.toNamed(AppRoutes.privacyPolicy),
        ),
        SettingsItem(
          icon: Icons.notifications_outlined,
          label: 'Notification Settings',
          onTap: () => Get.toNamed(AppRoutes.notificationSettings),
        ),
        SettingsItem(
          icon: Icons.lock_outline,
          label: 'Change Password',
          onTap: () => Get.toNamed(AppRoutes.changePassword),
        ),
        SettingsItem(
          icon: Icons.person_outline,
          label: 'Edit Profile',
          onTap: () => Get.toNamed(AppRoutes.editProfile),
        ),
        SettingsItem(
          icon: Icons.delete_outline,
          label: 'Delete Account',
          isDestructive: true,
          onTap: () => _confirmDeleteAccount(context),
        ),
        SettingsItem(
          icon: Icons.logout,
          label: 'Logout',
          isDestructive: true,
          onTap: () => _confirmLogout(context),
        ),
      ];

  Future<void> _showAppearanceSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Obx(
          () => RadioGroup<ThemeMode>(
            groupValue: _themeController.themeMode.value,
            onChanged: (value) {
              if (value != null) _themeController.setThemeMode(value);
              Navigator.of(sheetContext).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(title: Text(_themeModeLabel(mode)), value: mode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System default',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await AppBottomSheet.confirm(
      context,
      title: 'Delete account',
      message: 'This will permanently delete your account. This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    isDeletingAccount.value = true;
    final result = await _profileRepository.deleteAccount();
    isDeletingAccount.value = false;

    result.fold(
      (error) => Get.snackbar('Could not delete account', error.message),
      (_) async {
        await _sessionService.clear();
        Get.offAllNamed(AppRoutes.login);
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await AppBottomSheet.confirm(
      context,
      title: 'Log out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log out',
      isDestructive: true,
    );
    if (!confirmed) return;

    await _sessionService.clear();
    await AnalyticsService.logLogout();
    Get.offAllNamed(AppRoutes.login);
  }
}
