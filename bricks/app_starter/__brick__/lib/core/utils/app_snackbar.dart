import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

/// Thin wrapper over `Get.snackbar` for the common "this succeeded" case, so
/// success feedback looks the same everywhere instead of relying on GetX's
/// default styling.
abstract class AppSnackbar {
  AppSnackbar._();

  static void success(String title, String message) {
    Get.snackbar(title, message, backgroundColor: AppColors.success, colorText: Colors.white);
  }
}
