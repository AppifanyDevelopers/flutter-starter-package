import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:update_available/update_available.dart';

import '../utils/url_launcher_utils.dart';
import 'app_update_dialog.dart';

class AppUpdateService {
  AppUpdateService._();

  /// Checks the store listing and, if a newer version exists, blocks with a
  /// dialog until the user taps "Update now". Returns whether an update was
  /// prompted, so the caller can decide whether to continue navigating.
  ///
  /// Store URLs are placeholders until this app is actually published --
  /// see docs/POST_GEN_MANUAL_STEPS.md.
  static Future<bool> checkAndPromptIfNeeded(
    BuildContext context, {
    required String iosAppStoreUrl,
    required String androidAppStoreUrl,
  }) async {
    if (kIsWeb) return false;

    Availability availability;
    try {
      availability = await getUpdateAvailability();
    } catch (_) {
      // No real store listing yet for a freshly generated app -- no-op.
      return false;
    }

    if (availability is! UpdateAvailable) return false;
    if (!context.mounted) return false;

    await AppUpdateDialog.show(
      context,
      onUpdate: () => openStore(
        iosAppStoreUrl: iosAppStoreUrl,
        androidAppStoreUrl: androidAppStoreUrl,
      ),
    );
    return true;
  }

  static Future<void> openStore({
    required String iosAppStoreUrl,
    required String androidAppStoreUrl,
  }) {
    return UrlLauncherUtils.openUrl(Platform.isIOS ? iosAppStoreUrl : androidAppStoreUrl);
  }
}
