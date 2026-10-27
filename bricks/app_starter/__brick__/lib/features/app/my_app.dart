import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_configuration.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/keyboard.dart';
import '../../core/widgets/environment_banner.dart';
import '../../core/widgets/offline_banner.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: "{{{app_name_dart}}}",
        theme: AppTheme.light(AppColors.seed),
        darkTheme: AppTheme.dark(AppColors.seed),
        themeMode: themeController.themeMode.value,
        initialRoute: AppRoutes.splash,
        getPages: AppRoutes.pages,
        defaultTransition: Transition.fadeIn,
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();

          final content = EnvironmentBanner(
            environment: AppConfiguration.current.environment,
            child: child,
          );

          return DismissKeyboardOnTap(
            child: Column(
              children: [
                const OfflineBanner(),
                Expanded(child: content),
              ],
            ),
          );
        },
      ),
    );
  }
}
