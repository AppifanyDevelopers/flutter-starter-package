import 'package:flutter/material.dart';

import '../build_variants/app_environment.dart';

/// The corner ribbon on non-production builds: red STAGING or blue DI at the
/// top-left, matching the ribbon drawn on that flavor's launcher icon.
/// Production gets no ribbon.
class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({super.key, required this.environment, required this.child});

  final AppEnvironment environment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = environment.bannerLabel;
    if (label == null) return child;
    return Banner(
      message: label,
      location: BannerLocation.topStart,
      color: (environment == AppEnvironment.di ? Colors.blue : Colors.red).withValues(alpha: 0.8),
      child: child,
    );
  }
}
